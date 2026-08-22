import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/daily_health_summary_table.dart';
import '../tables/health_metrics_table.dart';
import '../tables/heart_rate_samples_table.dart';
import '../tables/sleep_sessions_table.dart';
import '../tables/activities_table.dart';

part 'health_metrics_dao.g.dart';

/// All queries here take an explicit [userId] and filter by it — no method
/// on this DAO may return another family member's rows (hard constraint:
/// every DAO method takes user_id and every query filters by it).
@DriftAccessor(tables: [
  HealthMetrics,
  DailyHealthSummaries,
  HeartRateSamples,
  SleepSessions,
  Activities,
])
class HealthMetricsDao extends DatabaseAccessor<AppDatabase> with _$HealthMetricsDaoMixin {
  HealthMetricsDao(super.db);

  Future<void> insertMetric(HealthMetricsCompanion metric) => into(healthMetrics).insert(metric);

  Future<void> insertMetrics(List<HealthMetricsCompanion> metrics) async {
    await batch((b) => b.insertAll(healthMetrics, metrics, mode: InsertMode.insertOrReplace));
  }

  /// Metrics of [metricType] for [userId] within [from, to], ascending by time.
  Future<List<HealthMetric>> getMetricsInRange({
    required String userId,
    required String metricType,
    required DateTime from,
    required DateTime to,
  }) {
    return (select(healthMetrics)
          ..where((t) =>
              t.userId.equals(userId) &
              t.metricType.equals(metricType) &
              t.timestamp.isBiggerOrEqualValue(from) &
              t.timestamp.isSmallerOrEqualValue(to))
          ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]))
        .get();
  }

  Stream<List<HealthMetric>> watchMetricsInRange({
    required String userId,
    required String metricType,
    required DateTime from,
    required DateTime to,
  }) {
    return (select(healthMetrics)
          ..where((t) =>
              t.userId.equals(userId) &
              t.metricType.equals(metricType) &
              t.timestamp.isBiggerOrEqualValue(from) &
              t.timestamp.isSmallerOrEqualValue(to))
          ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]))
        .watch();
  }

  Future<void> upsertDailySummary(DailyHealthSummariesCompanion summary) {
    return into(dailyHealthSummaries).insertOnConflictUpdate(summary);
  }

  Future<List<DailyHealthSummary>> getDailySummaries({
    required String userId,
    required DateTime from,
    required DateTime to,
  }) {
    return (select(dailyHealthSummaries)
          ..where((t) =>
              t.userId.equals(userId) &
              t.date.isBiggerOrEqualValue(from) &
              t.date.isSmallerOrEqualValue(to))
          ..orderBy([(t) => OrderingTerm.asc(t.date)]))
        .get();
  }

  Stream<List<DailyHealthSummary>> watchDailySummaries({
    required String userId,
    required DateTime from,
    required DateTime to,
  }) {
    return (select(dailyHealthSummaries)
          ..where((t) =>
              t.userId.equals(userId) &
              t.date.isBiggerOrEqualValue(from) &
              t.date.isSmallerOrEqualValue(to))
          ..orderBy([(t) => OrderingTerm.asc(t.date)]))
        .watch();
  }

  Future<DailyHealthSummary?> getLatestSummary(String userId) {
    return (select(dailyHealthSummaries)
          ..where((t) => t.userId.equals(userId))
          ..orderBy([(t) => OrderingTerm.desc(t.date)])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<void> insertSleepSession(SleepSessionsCompanion session) => into(sleepSessions).insert(session);

  Future<List<SleepSession>> getSleepSessions({
    required String userId,
    required DateTime from,
    required DateTime to,
  }) {
    return (select(sleepSessions)
          ..where((t) =>
              t.userId.equals(userId) &
              t.startTime.isBiggerOrEqualValue(from) &
              t.startTime.isSmallerOrEqualValue(to))
          ..orderBy([(t) => OrderingTerm.asc(t.startTime)]))
        .get();
  }

  Future<void> insertActivity(ActivitiesCompanion activity) => into(activities).insert(activity);

  Future<List<Activity>> getActivities({
    required String userId,
    required DateTime from,
    required DateTime to,
  }) {
    return (select(activities)
          ..where((t) =>
              t.userId.equals(userId) &
              t.startTime.isBiggerOrEqualValue(from) &
              t.startTime.isSmallerOrEqualValue(to))
          ..orderBy([(t) => OrderingTerm.desc(t.startTime)]))
        .get();
  }

  Future<void> insertHeartRateSamples(List<HeartRateSamplesCompanion> samples) async {
    await batch((b) => b.insertAll(heartRateSamples, samples, mode: InsertMode.insertOrReplace));
  }

  Future<List<HeartRateSample>> getHeartRateSamples({
    required String userId,
    required DateTime from,
    required DateTime to,
  }) {
    return (select(heartRateSamples)
          ..where((t) =>
              t.userId.equals(userId) &
              t.timestamp.isBiggerOrEqualValue(from) &
              t.timestamp.isSmallerOrEqualValue(to))
          ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]))
        .get();
  }
}
