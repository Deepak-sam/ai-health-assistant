import 'models/health_models.dart';

/// ARCHITECTURE.md §6 — verbatim Dart signature. `HealthConnectProvider`
/// and `GarminProvider` implement this; `FakeHealthProvider` implements it
/// for development with deterministic sample data. Every implementation is
/// swappable/testable purely via this interface — no caller depends on a
/// concrete provider type.
abstract class HealthProvider {
  String get providerId;
  Future<bool> isConnected();
  Future<void> connect();
  Future<void> disconnect();
  Future<SyncResult> sync({DateTime? since});
  Future<DailySummary> getDailySummary(DateTime date);
  Future<List<SleepSession>> getSleep(DateRange range);
  Future<List<HeartRateSample>> getHeartRate(DateRange range);
  Future<List<Activity>> getActivities(DateRange range);
  Future<List<HealthMetric>> getMetrics(String metricType, DateRange range);
}
