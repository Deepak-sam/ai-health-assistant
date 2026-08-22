import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/repositories/alert_repository.dart';
import '../../shared/repositories/health_repository.dart';
import '../../shared/services/notification_service.dart';
import '../health/models/health_models.dart' as domain;
import 'alert_rule_evaluator.dart';

/// Runs [AlertRuleEvaluator] against every enabled rule on-device, after a
/// sync completes and on a periodic local timer (ARCHITECTURE.md §10). This
/// is the only place evaluation results turn into `alert_events` rows and
/// local notifications — evaluation itself stays pure and untestable-free
/// of plugins inside `AlertRuleEvaluator`.
///
/// Note: rules are evaluated against `health_metrics` at whatever
/// resolution that metric type is stored — this works cleanly for
/// once/day metrics (resting_heart_rate, steps, weight) but a
/// high-frequency type like raw `heart_rate` would need day-bucketing
/// first. Phase 1 alert rules are expected to target daily-resolution
/// metrics only.
class AlertEvaluationService {
  AlertEvaluationService({
    required this.alertRepository,
    required this.healthRepository,
    required this.notificationService,
    this.evaluator = const AlertRuleEvaluator(),
  });

  final AlertRepository alertRepository;
  final HealthRepository healthRepository;
  final NotificationService notificationService;
  final AlertRuleEvaluator evaluator;

  Future<void> evaluateAll(String userId) async {
    final rules = await alertRepository.getRules(userId);
    for (final rule in rules.where((r) => r.enabled)) {
      final condition = AlertConditionSpec.fromJson(jsonDecode(rule.conditionJson) as Map<String, dynamic>);
      final spec = AlertRuleSpec(metricType: rule.metricType, condition: condition, window: rule.window);

      final lookbackDays = (condition.baselineWindowDays ?? 30) + (condition.consecutiveCount ?? 1) + 5;
      final series = await healthRepository.getMetrics(
        userId: userId,
        metricType: rule.metricType,
        range: domain.DateRange.lastDays(lookbackDays),
      );

      final result = evaluator.evaluate(spec, series);
      if (!result.fired || result.message == null || result.triggeringValue == null) continue;

      final isNew = await alertRepository.recordFiringIfNew(
        userId: userId,
        ruleId: rule.id,
        triggeringValue: result.triggeringValue!,
        message: result.message!,
      );
      if (isNew) {
        await notificationService.showAlertNotification(
          id: rule.id.hashCode,
          title: 'Health alert',
          body: result.message!,
        );
      }
    }
  }
}

final alertEvaluationServiceProvider = Provider<AlertEvaluationService>((ref) {
  return AlertEvaluationService(
    alertRepository: ref.watch(alertRepositoryProvider),
    healthRepository: ref.watch(healthRepositoryProvider),
    notificationService: ref.watch(notificationServiceProvider),
  );
});
