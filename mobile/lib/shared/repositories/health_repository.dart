import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/database/app_database.dart' as db;
import '../../core/database/daos/health_metrics_dao.dart';
import '../../core/networking/dio_client.dart';
import '../../core/security/secure_token_storage.dart';
import '../../features/garmin/garmin_provider.dart';
import '../../features/health/fake_health_provider.dart';
import '../../features/health/health_provider.dart';
import '../../features/health/models/health_models.dart' as domain;
import '../../features/health_connect/health_connect_provider.dart';

/// Thin façade over [HealthMetricsDao]. Everything reads from the on-device
/// Drift database — the local source of truth (ARCHITECTURE.md §9) — never
/// directly from a `HealthProvider` at render time; `HealthProvider`s are
/// only consulted by `SyncService`, which writes their results into Drift.
///
/// Every method takes an explicit [userId] and forwards it straight into
/// the DAO's `WHERE user_id = ?` filter (hard constraint #5).
class HealthRepository {
  HealthRepository(this._dao);

  final HealthMetricsDao _dao;

  Future<List<domain.HealthMetric>> getMetrics({
    required String userId,
    required String metricType,
    required domain.DateRange range,
  }) async {
    final rows = await _dao.getMetricsInRange(
      userId: userId,
      metricType: metricType,
      from: range.start,
      to: range.end,
    );
    return rows.map(_metricToDomain).toList();
  }

  Stream<List<domain.HealthMetric>> watchMetrics({
    required String userId,
    required String metricType,
    required domain.DateRange range,
  }) {
    return _dao
        .watchMetricsInRange(userId: userId, metricType: metricType, from: range.start, to: range.end)
        .map((rows) => rows.map(_metricToDomain).toList());
  }

  Future<db.DailyHealthSummary?> getLatestDailySummary(String userId) => _dao.getLatestSummary(userId);

  Future<List<db.DailyHealthSummary>> getDailySummaries({
    required String userId,
    required domain.DateRange range,
  }) {
    return _dao.getDailySummaries(userId: userId, from: range.start, to: range.end);
  }

  Stream<List<db.DailyHealthSummary>> watchDailySummaries({
    required String userId,
    required domain.DateRange range,
  }) {
    return _dao.watchDailySummaries(userId: userId, from: range.start, to: range.end);
  }

  Future<List<db.SleepSession>> getSleepSessions({required String userId, required domain.DateRange range}) {
    return _dao.getSleepSessions(userId: userId, from: range.start, to: range.end);
  }

  Future<List<db.Activity>> getActivities({required String userId, required domain.DateRange range}) {
    return _dao.getActivities(userId: userId, from: range.start, to: range.end);
  }

  domain.HealthMetric _metricToDomain(db.HealthMetric row) => domain.HealthMetric(
        metricType: row.metricType,
        value: row.value,
        unit: row.unit,
        timestamp: row.timestamp,
        provider: row.provider,
      );
}

final healthRepositoryProvider = Provider<HealthRepository>((ref) {
  final database = ref.watch(db.appDatabaseProvider);
  return HealthRepository(database.healthMetricsDao);
});

/// The Health Connect provider — real or fake depending on
/// [AppConfig.useFakeHealthProvider]. Always present; Health Connect is the
/// baseline integration (ARCHITECTURE.md §7).
final healthConnectProviderInstanceProvider = Provider<HealthProvider>((ref) {
  return AppConfig.useFakeHealthProvider ? FakeHealthProvider(providerId: 'health_connect') : HealthConnectProvider();
});

/// The Garmin provider, only when [AppConfig.garminEnabled] — null
/// otherwise so callers/UI can hide Garmin entirely behind the flag
/// (ARCHITECTURE.md §1/§6 Decision).
final garminProviderInstanceProvider = Provider<HealthProvider?>((ref) {
  if (!AppConfig.garminEnabled) return null;
  if (AppConfig.useFakeHealthProvider) return FakeHealthProvider(seedOffset: 97, providerId: 'garmin');
  return GarminProvider(
    dio: ref.watch(dioProvider),
    tokenStorage: ref.watch(secureTokenStorageProvider),
  );
});

/// All providers currently in play, for [SyncService] to iterate.
final activeHealthProvidersProvider = Provider<List<HealthProvider>>((ref) {
  final garmin = ref.watch(garminProviderInstanceProvider);
  return [
    ref.watch(healthConnectProviderInstanceProvider),
    if (garmin != null) garmin,
  ];
});
