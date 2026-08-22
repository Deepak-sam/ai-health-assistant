/// Plain Dart domain models for the `HealthProvider` interface
/// (ARCHITECTURE.md §6). Deliberately independent of Drift/SQLite — these
/// are what `BaselineCalculator` and every `HealthProvider` implementation
/// speak, so the calculator stays a pure, unit-testable function of data
/// with no network/db dependency.
///
/// NOTE on naming: several of these names (`HealthMetric`, `SleepSession`,
/// `HeartRateSample`, `Activity`) are shared with Drift's generated row
/// classes for the corresponding tables (see core/database/tables/). That's
/// intentional — ARCHITECTURE.md §6 pins these exact type names for the
/// interface. Any file that needs both the domain model *and* the Drift row
/// class (repositories, SyncService) must import the database with a
/// prefix, e.g. `import '.../app_database.dart' as db;` and refer to
/// `db.HealthMetric` etc. Domain/business-logic code (BaselineCalculator,
/// HealthProvider implementations) never imports Drift and never hits this
/// collision.
library health_models;

class DateRange {
  const DateRange({required this.start, required this.end});

  factory DateRange.lastDays(int days, {DateTime? now}) {
    final end = now ?? DateTime.now();
    return DateRange(start: end.subtract(Duration(days: days)), end: end);
  }

  final DateTime start;
  final DateTime end;
}

class HealthMetric {
  const HealthMetric({
    required this.metricType,
    required this.value,
    required this.unit,
    required this.timestamp,
    this.provider = 'manual',
  });

  final String metricType;
  final double value;
  final String unit;
  final DateTime timestamp;
  final String provider;
}

class DailySummary {
  const DailySummary({
    required this.date,
    this.steps,
    this.caloriesActive,
    this.caloriesTotal,
    this.activeMinutes,
    this.distanceM,
    this.restingHeartRate,
    this.hrvMs,
    this.sleepDurationMin,
    this.sleepScore,
    this.weightKg,
  });

  final DateTime date;
  final int? steps;
  final int? caloriesActive;
  final int? caloriesTotal;
  final int? activeMinutes;
  final double? distanceM;
  final double? restingHeartRate;
  final double? hrvMs;
  final int? sleepDurationMin;
  final int? sleepScore;
  final double? weightKg;
}

class SleepSession {
  const SleepSession({
    required this.startTime,
    required this.endTime,
    required this.durationMin,
    this.sleepScore,
    this.stages,
    this.restingHeartRate,
    this.hrvMs,
  });

  final DateTime startTime;
  final DateTime endTime;
  final int durationMin;
  final int? sleepScore;
  /// e.g. {"deep": 90, "light": 240, "rem": 80, "awake": 15} (minutes)
  final Map<String, int>? stages;
  final double? restingHeartRate;
  final double? hrvMs;
}

class HeartRateSample {
  const HeartRateSample({required this.timestamp, required this.bpm, this.context});

  final DateTime timestamp;
  final int bpm;
  final String? context; // 'resting' | 'activity'
}

class Activity {
  const Activity({
    required this.activityType,
    required this.startTime,
    required this.durationMin,
    this.distanceM,
    this.calories,
    this.avgHeartRate,
    this.maxHeartRate,
    this.trainingLoad,
  });

  final String activityType; // 'run' | 'ride' | 'strength' | ...
  final DateTime startTime;
  final int durationMin;
  final double? distanceM;
  final int? calories;
  final double? avgHeartRate;
  final double? maxHeartRate;
  final double? trainingLoad;
}

class SyncResult {
  const SyncResult({
    required this.providerId,
    required this.success,
    this.metricsSynced = 0,
    this.error,
    this.syncedAt,
  });

  final String providerId;
  final bool success;
  final int metricsSynced;
  final String? error;
  final DateTime? syncedAt;
}
