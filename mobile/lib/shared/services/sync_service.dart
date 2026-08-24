import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart' as db;
import '../../core/database/daos/device_connections_dao.dart';
import '../../core/database/daos/health_metrics_dao.dart';
import '../../core/database/daos/sync_state_dao.dart';
import '../../features/health/health_provider.dart';
import '../../features/health/models/health_models.dart' as domain;
import '../repositories/health_repository.dart';

/// The metric types pulled per provider per sync via `getMetrics` —
/// exactly the metric types `HealthConnectProvider` can map to a requested
/// Health Connect scope (ARCHITECTURE.md §7). `heart_rate` is fetched
/// separately via `getHeartRate` (high-frequency, its own table), and
/// sleep duration/score come from `getSleep`/`getDailySummary` rather than
/// this generic list.
const _syncedMetricTypes = [
  'steps',
  'resting_heart_rate',
  'calories_active',
  'calories_total',
  'distance',
  'weight',
];

/// Calls every connected `HealthProvider`'s data-fetch methods for the
/// window since its last successful sync and writes the results into the
/// local Drift database — the only place providers' data ever lands
/// (`HealthProvider` implementations never touch Drift themselves, keeping
/// them swappable/testable per ARCHITECTURE.md §6/§9).
class SyncService {
  SyncService({
    required this.providers,
    required this.healthMetricsDao,
    required this.syncStateDao,
    required this.deviceConnectionsDao,
  });

  final List<HealthProvider> providers;
  final HealthMetricsDao healthMetricsDao;
  final SyncStateDao syncStateDao;
  final DeviceConnectionsDao deviceConnectionsDao;
  final _uuid = const Uuid();

  Future<void> syncAll(String userId) async {
    for (final provider in providers) {
      await _syncProvider(userId, provider);
    }
  }

  Future<void> _syncProvider(String userId, HealthProvider provider) async {
    try {
      final connected = await provider.isConnected();
      if (!connected) {
        await deviceConnectionsDao.upsertStatus(
          userId: userId,
          provider: provider.providerId,
          status: 'disconnected',
        );
        return;
      }

      final state = await syncStateDao.getState(userId: userId, provider: provider.providerId);
      final since = state?.lastSyncedAt ?? DateTime.now().subtract(const Duration(days: 30));
      final now = DateTime.now();
      final range = domain.DateRange(start: since, end: now);

      var totalSynced = 0;

      for (final metricType in _syncedMetricTypes) {
        final metrics = await provider.getMetrics(metricType, range);
        if (metrics.isEmpty) continue;
        await healthMetricsDao.insertMetrics(metrics
            .map((m) => db.HealthMetricsCompanion.insert(
                  id: _uuid.v4(),
                  userId: userId,
                  provider: provider.providerId,
                  metricType: m.metricType,
                  value: m.value,
                  unit: m.unit,
                  timestamp: m.timestamp,
                  createdAt: DateTime.now(),
                ))
            .toList());
        totalSynced += metrics.length;
      }

      final sleepSessions = await provider.getSleep(range);
      for (final s in sleepSessions) {
        await healthMetricsDao.insertSleepSession(db.SleepSessionsCompanion.insert(
          id: _uuid.v4(),
          userId: userId,
          provider: provider.providerId,
          startTime: s.startTime,
          endTime: s.endTime,
          durationMin: s.durationMin,
          sleepScore: Value(s.sleepScore),
          stagesJson: Value(s.stages == null ? null : jsonEncode(s.stages)),
          restingHeartRate: Value(s.restingHeartRate),
          hrvMs: Value(s.hrvMs),
        ));
      }
      totalSynced += sleepSessions.length;

      final activities = await provider.getActivities(range);
      for (final a in activities) {
        await healthMetricsDao.insertActivity(db.ActivitiesCompanion.insert(
          id: _uuid.v4(),
          userId: userId,
          provider: provider.providerId,
          activityType: a.activityType,
          startTime: a.startTime,
          durationMin: a.durationMin,
          distanceM: Value(a.distanceM),
          calories: Value(a.calories),
          avgHeartRate: Value(a.avgHeartRate),
          maxHeartRate: Value(a.maxHeartRate),
          trainingLoad: Value(a.trainingLoad),
        ));
      }
      totalSynced += activities.length;

      // Daily summaries, one upsert per day in range — cheap since
      // getDailySummary is typically backed by cached device data.
      for (var day = _dateOnly(range.start); !day.isAfter(_dateOnly(range.end)); day = day.add(const Duration(days: 1))) {
        final summary = await provider.getDailySummary(day);
        await healthMetricsDao.upsertDailySummary(db.DailyHealthSummariesCompanion.insert(
          id: _uuid.v4(),
          userId: userId,
          date: day,
          steps: Value(summary.steps),
          caloriesActive: Value(summary.caloriesActive),
          caloriesTotal: Value(summary.caloriesTotal),
          activeMinutes: Value(summary.activeMinutes),
          distanceM: Value(summary.distanceM),
          restingHeartRate: Value(summary.restingHeartRate),
          hrvMs: Value(summary.hrvMs),
          sleepDurationMin: Value(summary.sleepDurationMin),
          sleepScore: Value(summary.sleepScore),
          weightKg: Value(summary.weightKg),
          updatedAt: DateTime.now(),
        ));
      }

      await syncStateDao.updateCursor(userId: userId, provider: provider.providerId, syncedAt: now);
      await deviceConnectionsDao.upsertStatus(
        userId: userId,
        provider: provider.providerId,
        status: 'connected',
        lastSyncAt: now,
      );
    } catch (e) {
      // A provider without a real data backend yet (e.g. Garmin before the
      // backend data-sync endpoint exists — see features/garmin/garmin_provider.dart)
      // must not take down the whole sync loop for other providers.
      await deviceConnectionsDao.upsertStatus(
        userId: userId,
        provider: provider.providerId,
        status: 'error',
        lastError: e.toString(),
      );
    }
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}

final syncServiceProvider = Provider<SyncService>((ref) {
  final database = ref.watch(db.appDatabaseProvider);
  return SyncService(
    providers: ref.watch(activeHealthProvidersProvider),
    healthMetricsDao: database.healthMetricsDao,
    syncStateDao: database.syncStateDao,
    deviceConnectionsDao: database.deviceConnectionsDao,
  );
});
