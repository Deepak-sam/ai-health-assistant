import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/alert_events_table.dart';
import '../tables/alert_rules_table.dart';

part 'alert_rules_dao.g.dart';

@DriftAccessor(tables: [AlertRules, AlertEvents])
class AlertRulesDao extends DatabaseAccessor<AppDatabase> with _$AlertRulesDaoMixin {
  AlertRulesDao(super.db);

  Future<void> insertRule(AlertRulesCompanion rule) => into(alertRules).insert(rule);

  Future<void> setEnabled({required String userId, required String ruleId, required bool enabled}) {
    return (update(alertRules)..where((t) => t.userId.equals(userId) & t.id.equals(ruleId)))
        .write(AlertRulesCompanion(enabled: Value(enabled)));
  }

  Future<void> deleteRule({required String userId, required String ruleId}) {
    return (delete(alertRules)..where((t) => t.userId.equals(userId) & t.id.equals(ruleId))).go();
  }

  Future<List<AlertRule>> getRules(String userId) {
    return (select(alertRules)
          ..where((t) => t.userId.equals(userId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  Stream<List<AlertRule>> watchRules(String userId) {
    return (select(alertRules)
          ..where((t) => t.userId.equals(userId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  Future<List<AlertRule>> getEnabledRules(String userId) {
    return (select(alertRules)..where((t) => t.userId.equals(userId) & t.enabled.equals(true))).get();
  }

  Future<void> insertEvent(AlertEventsCompanion event) => into(alertEvents).insert(event);

  Future<List<AlertEvent>> getEvents(String userId, {int limit = 50}) {
    return (select(alertEvents)
          ..where((t) => t.userId.equals(userId))
          ..orderBy([(t) => OrderingTerm.desc(t.triggeredAt)])
          ..limit(limit))
        .get();
  }

  Stream<List<AlertEvent>> watchEvents(String userId, {int limit = 50}) {
    return (select(alertEvents)
          ..where((t) => t.userId.equals(userId))
          ..orderBy([(t) => OrderingTerm.desc(t.triggeredAt)])
          ..limit(limit))
        .watch();
  }

  /// Most recent event for a rule, used by [AlertRuleEvaluator] to avoid
  /// re-firing the same day's breach repeatedly.
  Future<AlertEvent?> getLatestEventForRule({required String userId, required String ruleId}) {
    return (select(alertEvents)
          ..where((t) => t.userId.equals(userId) & t.alertRuleId.equals(ruleId))
          ..orderBy([(t) => OrderingTerm.desc(t.triggeredAt)])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<void> acknowledgeEvent({required String userId, required String eventId}) {
    return (update(alertEvents)..where((t) => t.userId.equals(userId) & t.id.equals(eventId)))
        .write(const AlertEventsCompanion(acknowledged: Value(true)));
  }
}
