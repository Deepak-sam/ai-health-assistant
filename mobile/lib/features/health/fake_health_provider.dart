import 'dart:math';

import 'health_provider.dart';
import 'models/health_models.dart';

/// Deterministic sample-data provider for development/UI work when no real
/// Health Connect / Garmin data is available (ARCHITECTURE.md §1: "app ships
/// and works via Health Connect / manual entry"). Deterministic means the
/// same call with the same `DateTime` always returns the same numbers —
/// achieved by seeding `Random` from the day-of-year rather than wall-clock
/// entropy, so screenshots/tests are stable across runs.
class FakeHealthProvider implements HealthProvider {
  FakeHealthProvider({this.seedOffset = 0, String providerId = 'fake'}) : _providerId = providerId;

  /// Shifts the deterministic seed — lets two fake providers (e.g. a
  /// "family member A" vs "family member B" demo, or a fake standing in for
  /// Garmin vs Health Connect) produce different but still-reproducible
  /// series.
  final int seedOffset;
  final String _providerId;

  bool _connected = true;

  int _seedFor(DateTime date) => date.year * 1000 + date.dayOfYearApprox + seedOffset;

  @override
  String get providerId => _providerId;

  @override
  Future<bool> isConnected() async => _connected;

  @override
  Future<void> connect() async => _connected = true;

  @override
  Future<void> disconnect() async => _connected = false;

  @override
  Future<SyncResult> sync({DateTime? since}) async {
    return SyncResult(providerId: providerId, success: true, metricsSynced: 42, syncedAt: DateTime.now());
  }

  @override
  Future<DailySummary> getDailySummary(DateTime date) async {
    final rng = Random(_seedFor(date));
    return DailySummary(
      date: DateTime(date.year, date.month, date.day),
      steps: 6000 + rng.nextInt(5000),
      caloriesActive: 300 + rng.nextInt(300),
      caloriesTotal: 1900 + rng.nextInt(500),
      activeMinutes: 20 + rng.nextInt(60),
      distanceM: 3000 + rng.nextDouble() * 4000,
      restingHeartRate: 55 + rng.nextDouble() * 10,
      hrvMs: 38 + rng.nextDouble() * 15,
      sleepDurationMin: 380 + rng.nextInt(120),
      sleepScore: 60 + rng.nextInt(35),
      weightKg: 72 + rng.nextDouble() * 2 - 1,
    );
  }

  @override
  Future<List<SleepSession>> getSleep(DateRange range) async {
    final sessions = <SleepSession>[];
    for (var day = _dateOnly(range.start); !day.isAfter(range.end); day = day.add(const Duration(days: 1))) {
      final rng = Random(_seedFor(day));
      final start = DateTime(day.year, day.month, day.day - 1, 22, 30 + rng.nextInt(60));
      final durationMin = 380 + rng.nextInt(120);
      final end = start.add(Duration(minutes: durationMin));
      sessions.add(SleepSession(
        startTime: start,
        endTime: end,
        durationMin: durationMin,
        sleepScore: 60 + rng.nextInt(35),
        stages: {
          'deep': (durationMin * 0.18).round(),
          'light': (durationMin * 0.55).round(),
          'rem': (durationMin * 0.20).round(),
          'awake': (durationMin * 0.07).round(),
        },
        restingHeartRate: 55 + rng.nextDouble() * 10,
        hrvMs: 38 + rng.nextDouble() * 15,
      ));
    }
    return sessions;
  }

  @override
  Future<List<HeartRateSample>> getHeartRate(DateRange range) async {
    final samples = <HeartRateSample>[];
    for (var day = _dateOnly(range.start); !day.isAfter(range.end); day = day.add(const Duration(days: 1))) {
      final rng = Random(_seedFor(day));
      for (var hour = 0; hour < 24; hour += 2) {
        samples.add(HeartRateSample(
          timestamp: DateTime(day.year, day.month, day.day, hour),
          bpm: 58 + rng.nextInt(40),
          context: hour >= 0 && hour < 6 ? 'resting' : 'activity',
        ));
      }
    }
    return samples;
  }

  @override
  Future<List<Activity>> getActivities(DateRange range) async {
    final activities = <Activity>[];
    const types = ['run', 'ride', 'strength', 'walk'];
    for (var day = _dateOnly(range.start); !day.isAfter(range.end); day = day.add(const Duration(days: 1))) {
      final rng = Random(_seedFor(day));
      if (rng.nextDouble() < 0.55) {
        final type = types[rng.nextInt(types.length)];
        final durationMin = 20 + rng.nextInt(60);
        activities.add(Activity(
          activityType: type,
          startTime: DateTime(day.year, day.month, day.day, 7 + rng.nextInt(12)),
          durationMin: durationMin,
          distanceM: type == 'run' || type == 'ride' ? durationMin * (type == 'run' ? 160.0 : 400.0) : null,
          calories: 150 + rng.nextInt(400),
          avgHeartRate: 120 + rng.nextDouble() * 30,
          maxHeartRate: 150 + rng.nextDouble() * 30,
          trainingLoad: 40 + rng.nextDouble() * 80,
        ));
      }
    }
    return activities;
  }

  @override
  Future<List<HealthMetric>> getMetrics(String metricType, DateRange range) async {
    final metrics = <HealthMetric>[];
    for (var day = _dateOnly(range.start); !day.isAfter(range.end); day = day.add(const Duration(days: 1))) {
      final rng = Random(_seedFor(day));
      final value = _valueFor(metricType, rng);
      if (value == null) continue;
      metrics.add(HealthMetric(
        metricType: metricType,
        value: value,
        unit: _unitFor(metricType),
        timestamp: DateTime(day.year, day.month, day.day, 8),
        provider: providerId,
      ));
    }
    return metrics;
  }

  double? _valueFor(String metricType, Random rng) {
    switch (metricType) {
      case 'resting_heart_rate':
        return 55 + rng.nextDouble() * 10;
      case 'hrv':
        return 38 + rng.nextDouble() * 15;
      case 'steps':
        return (6000 + rng.nextInt(5000)).toDouble();
      case 'sleep_duration':
        return (380 + rng.nextInt(120)).toDouble();
      case 'sleep_score':
        return (60 + rng.nextInt(35)).toDouble();
      case 'calories_active':
        return (300 + rng.nextInt(300)).toDouble();
      case 'calories_total':
        return (1900 + rng.nextInt(500)).toDouble();
      case 'distance':
        return 3000 + rng.nextDouble() * 4000;
      case 'weight':
        return 72 + rng.nextDouble() * 2 - 1;
      case 'body_battery':
        return (30 + rng.nextInt(70)).toDouble();
      case 'blood_oxygen':
        return 95 + rng.nextDouble() * 4;
      case 'vo2_max':
        return 38 + rng.nextDouble() * 12;
      case 'active_minutes':
        return (20 + rng.nextInt(60)).toDouble();
      case 'stress':
        return (10 + rng.nextInt(60)).toDouble();
      case 'heart_rate':
        return (58 + rng.nextInt(40)).toDouble();
      default:
        return null;
    }
  }

  String _unitFor(String metricType) {
    const units = {
      'resting_heart_rate': 'bpm',
      'hrv': 'ms',
      'steps': 'count',
      'sleep_duration': 'min',
      'sleep_score': 'score',
      'calories_active': 'kcal',
      'calories_total': 'kcal',
      'distance': 'm',
      'weight': 'kg',
      'body_battery': 'score',
      'blood_oxygen': 'percent',
      'vo2_max': 'ml/kg/min',
      'active_minutes': 'min',
      'stress': 'score',
      'heart_rate': 'bpm',
    };
    return units[metricType] ?? '';
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}

extension on DateTime {
  int get dayOfYearApprox => difference(DateTime(year, 1, 1)).inDays;
}
