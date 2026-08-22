import 'package:health/health.dart';

import '../health/health_provider.dart';
import '../health/models/health_models.dart' as domain;

/// `HealthProvider` implementation backed by the `health` plugin, targeting
/// Health Connect on Android (ARCHITECTURE.md §7). The `health` plugin's
/// unified `HealthDataType` enum is shared with its HealthKit path, which is
/// why this same class is expected to double as the iOS HealthKit provider
/// later with minimal change (per §7) — only Health Connect scopes are
/// requested/wired in Phase 1.
///
/// NOTE for the engineer picking this up with a real toolchain: the `health`
/// package's exact `HealthDataType` member names have shifted across major
/// versions. The names below are this package version's documented set as
/// of this writing; run `flutter pub get` and let the analyzer confirm each
/// enum member resolves, adjusting `_typeForMetric`/`_metricForType` if a
/// name has moved (e.g. `ACTIVE_ENERGY_BURNED` vs a Health-Connect-specific
/// active calories type).
class HealthConnectProvider implements HealthProvider {
  HealthConnectProvider({Health? health}) : _health = health ?? Health();

  final Health _health;

  /// Read scopes requested — exactly the list in ARCHITECTURE.md §7, no
  /// more. No write scopes are requested (§7: "No write scopes").
  static const List<HealthDataType> requestedTypes = [
    HealthDataType.STEPS,
    HealthDataType.HEART_RATE,
    HealthDataType.RESTING_HEART_RATE,
    HealthDataType.SLEEP_SESSION,
    HealthDataType.ACTIVE_ENERGY_BURNED, // Health Connect: ActiveCaloriesBurnedRecord
    HealthDataType.TOTAL_CALORIES_BURNED,
    HealthDataType.WEIGHT,
    HealthDataType.DISTANCE_DELTA,
    HealthDataType.WORKOUT,
  ];

  static final List<HealthDataAccess> _permissions =
      List.filled(requestedTypes.length, HealthDataAccess.READ);

  @override
  String get providerId => 'health_connect';

  @override
  Future<bool> isConnected() async {
    final granted = await _health.hasPermissions(requestedTypes, permissions: _permissions);
    return granted ?? false;
  }

  @override
  Future<void> connect() async {
    await _health.configure();
    final granted = await _health.requestAuthorization(requestedTypes, permissions: _permissions);
    if (!granted) {
      throw StateError('Health Connect permissions were not granted for all requested scopes.');
    }
  }

  @override
  Future<void> disconnect() async {
    // Health Connect exposes no app-initiated "revoke" call — the user
    // revokes access from the Health Connect app itself. This clears
    // nothing OS-level; the caller (SyncService/repository) is responsible
    // for updating `device_connections.status` to 'disconnected' locally.
  }

  @override
  Future<domain.SyncResult> sync({DateTime? since}) async {
    final range = domain.DateRange(
      start: since ?? DateTime.now().subtract(const Duration(days: 7)),
      end: DateTime.now(),
    );
    try {
      var count = 0;
      for (final type in requestedTypes) {
        final metricType = _metricForType(type);
        if (metricType == null) continue;
        final metrics = await getMetrics(metricType, range);
        count += metrics.length;
      }
      return domain.SyncResult(
        providerId: providerId,
        success: true,
        metricsSynced: count,
        syncedAt: DateTime.now(),
      );
    } catch (e) {
      return domain.SyncResult(providerId: providerId, success: false, error: e.toString());
    }
  }

  @override
  Future<domain.DailySummary> getDailySummary(DateTime date) async {
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final range = domain.DateRange(start: dayStart, end: dayEnd);

    final steps = await getMetrics('steps', range);
    final restingHr = await getMetrics('resting_heart_rate', range);
    final caloriesActive = await getMetrics('calories_active', range);
    final caloriesTotal = await getMetrics('calories_total', range);
    final distance = await getMetrics('distance', range);
    final weight = await getMetrics('weight', range);
    final sleep = await getSleep(range);

    final sleepToday = sleep.isNotEmpty ? sleep.first : null;

    return domain.DailySummary(
      date: dayStart,
      steps: steps.isEmpty ? null : steps.map((m) => m.value).reduce((a, b) => a + b).round(),
      caloriesActive: caloriesActive.isEmpty ? null : caloriesActive.fold(0.0, (a, m) => a + m.value).round(),
      caloriesTotal: caloriesTotal.isEmpty ? null : caloriesTotal.fold(0.0, (a, m) => a + m.value).round(),
      distanceM: distance.isEmpty ? null : distance.fold(0.0, (a, m) => a + m.value),
      restingHeartRate: restingHr.isEmpty ? null : restingHr.last.value,
      sleepDurationMin: sleepToday?.durationMin,
      sleepScore: sleepToday?.sleepScore,
      weightKg: weight.isEmpty ? null : weight.last.value,
    );
  }

  @override
  Future<List<domain.SleepSession>> getSleep(domain.DateRange range) async {
    final points = await _health.getHealthDataFromTypes(
      types: const [HealthDataType.SLEEP_SESSION],
      startTime: range.start,
      endTime: range.end,
    );
    return points.map((p) {
      final durationMin = p.dateTo.difference(p.dateFrom).inMinutes;
      return domain.SleepSession(
        startTime: p.dateFrom,
        endTime: p.dateTo,
        durationMin: durationMin,
        // Health Connect's SleepSessionRecord exposes stage breakdowns via
        // separate stage records the `health` plugin surfaces as distinct
        // data points in newer versions; Phase 1 stores only the overall
        // session here and leaves `stages`/`sleepScore` null until a
        // stage-aware query is wired up.
      );
    }).toList();
  }

  @override
  Future<List<domain.HeartRateSample>> getHeartRate(domain.DateRange range) async {
    final points = await _health.getHealthDataFromTypes(
      types: const [HealthDataType.HEART_RATE],
      startTime: range.start,
      endTime: range.end,
    );
    return points.map((p) {
      final value = p.value;
      final bpm = value is NumericHealthValue ? value.numericValue.round() : 0;
      return domain.HeartRateSample(timestamp: p.dateFrom, bpm: bpm);
    }).toList();
  }

  @override
  Future<List<domain.Activity>> getActivities(domain.DateRange range) async {
    final points = await _health.getHealthDataFromTypes(
      types: const [HealthDataType.WORKOUT],
      startTime: range.start,
      endTime: range.end,
    );
    return points.map((p) {
      final value = p.value;
      final workoutType = value is WorkoutHealthValue ? value.workoutActivityType.name.toLowerCase() : 'workout';
      return domain.Activity(
        activityType: workoutType,
        startTime: p.dateFrom,
        durationMin: p.dateTo.difference(p.dateFrom).inMinutes,
        distanceM: value is WorkoutHealthValue ? value.totalDistance?.toDouble() : null,
        calories: value is WorkoutHealthValue ? value.totalEnergyBurned?.round() : null,
      );
    }).toList();
  }

  @override
  Future<List<domain.HealthMetric>> getMetrics(String metricType, domain.DateRange range) async {
    final type = _typeForMetric(metricType);
    if (type == null) return const [];
    final points = await _health.getHealthDataFromTypes(
      types: [type],
      startTime: range.start,
      endTime: range.end,
    );
    return points
        .map((p) {
          final value = p.value;
          final numeric = value is NumericHealthValue ? value.numericValue.toDouble() : null;
          if (numeric == null) return null;
          return domain.HealthMetric(
            metricType: metricType,
            value: numeric,
            unit: p.unit.name,
            timestamp: p.dateFrom,
            provider: providerId,
          );
        })
        .whereType<domain.HealthMetric>()
        .toList();
  }

  /// Maps our internal `metric_type` (DATABASE_SCHEMA.md enum) to the
  /// plugin's `HealthDataType`.
  HealthDataType? _typeForMetric(String metricType) {
    switch (metricType) {
      case 'steps':
        return HealthDataType.STEPS;
      case 'heart_rate':
        return HealthDataType.HEART_RATE;
      case 'resting_heart_rate':
        return HealthDataType.RESTING_HEART_RATE;
      case 'calories_active':
        return HealthDataType.ACTIVE_ENERGY_BURNED;
      case 'calories_total':
        return HealthDataType.TOTAL_CALORIES_BURNED;
      case 'weight':
        return HealthDataType.WEIGHT;
      case 'distance':
        return HealthDataType.DISTANCE_DELTA;
      default:
        return null;
    }
  }

  /// Inverse of [_typeForMetric], used by [sync] to iterate requested types.
  String? _metricForType(HealthDataType type) {
    switch (type) {
      case HealthDataType.STEPS:
        return 'steps';
      case HealthDataType.HEART_RATE:
        return 'heart_rate';
      case HealthDataType.RESTING_HEART_RATE:
        return 'resting_heart_rate';
      case HealthDataType.ACTIVE_ENERGY_BURNED:
        return 'calories_active';
      case HealthDataType.TOTAL_CALORIES_BURNED:
        return 'calories_total';
      case HealthDataType.WEIGHT:
        return 'weight';
      case HealthDataType.DISTANCE_DELTA:
        return 'distance';
      default:
        return null;
    }
  }
}
