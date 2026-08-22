import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart' as db;
import '../../core/database/daos/alert_rules_dao.dart';
import '../../core/networking/dio_client.dart';
import '../models/alert_models.dart';

/// Talks to `POST /alerts/compile` (LLM, invoked once at creation time —
/// ARCHITECTURE.md §10) and persists the confirmed rule into `alert_rules`.
/// Evaluation itself never touches this repository or the network — that's
/// `AlertRuleEvaluator`, pure deterministic Dart against local data.
class AlertRepository {
  AlertRepository({required Dio dio, required AlertRulesDao dao})
      : _dio = dio,
        _dao = dao;

  final Dio _dio;
  final AlertRulesDao _dao;
  final _uuid = const Uuid();

  Future<AlertCompileResponse> compileRule(String naturalLanguageText) async {
    final request = AlertCompileRequest(text: naturalLanguageText);
    try {
      final response = await _dio.post<Map<String, dynamic>>('/alerts/compile', data: request.toJson());
      return AlertCompileResponse.fromJson(response.data!);
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  /// Called only after the user has seen and confirmed
  /// [AlertCompileResponse.confirmationText] — never persisted silently.
  Future<void> saveConfirmedRule({
    required String userId,
    required AlertCompileResponse compiled,
    required String createdFromText,
  }) async {
    await _dao.insertRule(db.AlertRulesCompanion.insert(
      id: _uuid.v4(),
      userId: userId,
      metricType: compiled.rule.metricType,
      conditionJson: jsonEncode(compiled.rule.condition.toJson()),
      window: compiled.rule.window,
      createdFromText: createdFromText,
      createdAt: DateTime.now(),
      enabled: const Value(true),
    ));
  }

  Future<List<db.AlertRule>> getRules(String userId) => _dao.getRules(userId);

  Stream<List<db.AlertRule>> watchRules(String userId) => _dao.watchRules(userId);

  Future<void> setEnabled({required String userId, required String ruleId, required bool enabled}) {
    return _dao.setEnabled(userId: userId, ruleId: ruleId, enabled: enabled);
  }

  Future<void> deleteRule({required String userId, required String ruleId}) {
    return _dao.deleteRule(userId: userId, ruleId: ruleId);
  }

  Stream<List<db.AlertEvent>> watchEvents(String userId) => _dao.watchEvents(userId);

  Future<void> acknowledgeEvent({required String userId, required String eventId}) {
    return _dao.acknowledgeEvent(userId: userId, eventId: eventId);
  }

  /// Records a firing, but only once per calendar day per rule — keeps
  /// `AlertRuleEvaluator` (which re-evaluates on every sync/timer tick)
  /// from spamming `alert_events`/notifications for a condition that's
  /// still true an hour later. Returns whether a new event was recorded.
  Future<bool> recordFiringIfNew({
    required String userId,
    required String ruleId,
    required double triggeringValue,
    required String message,
  }) async {
    final last = await _dao.getLatestEventForRule(userId: userId, ruleId: ruleId);
    final now = DateTime.now();
    if (last != null && _isSameDay(last.triggeredAt, now)) return false;
    await _dao.insertEvent(db.AlertEventsCompanion.insert(
      id: _uuid.v4(),
      alertRuleId: ruleId,
      userId: userId,
      triggeredAt: now,
      message: message,
      metricValue: triggeringValue,
    ));
    return true;
  }

  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
}

final alertRepositoryProvider = Provider<AlertRepository>((ref) {
  final database = ref.watch(db.appDatabaseProvider);
  return AlertRepository(dio: ref.watch(dioProvider), dao: database.alertRulesDao);
});
