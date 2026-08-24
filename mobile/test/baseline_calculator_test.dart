import 'package:family_health_assistant/features/health/baseline_calculator.dart';
import 'package:family_health_assistant/features/health/models/health_models.dart';
import 'package:flutter_test/flutter_test.dart';

HealthMetric _metric(double value, DateTime timestamp) => HealthMetric(
      metricType: 'resting_heart_rate',
      value: value,
      unit: 'bpm',
      timestamp: timestamp,
    );

void main() {
  const calculator = BaselineCalculator();
  final now = DateTime(2026, 1, 31, 12);

  group('average', () {
    test('returns 0 for an empty list', () {
      expect(calculator.average(const []), 0);
    });

    test('computes the arithmetic mean', () {
      expect(calculator.average([1, 2, 3, 4]), 2.5);
    });
  });

  group('stddev', () {
    test('returns 0 for fewer than two values', () {
      expect(calculator.stddev(const []), 0);
      expect(calculator.stddev([5]), 0);
    });

    test('computes sample standard deviation', () {
      // values: 2, 4, 4, 4, 5, 5, 7, 9 -> mean 5, sample stddev ~2.138
      final result = calculator.stddev([2, 4, 4, 4, 5, 5, 7, 9]);
      expect(result, closeTo(2.138, 0.01));
    });
  });

  group('windowStats — 7/30 day averages', () {
    test('7-day window only includes points within the last 7 days', () {
      final metrics = [
        _metric(58, now.subtract(const Duration(days: 1))),
        _metric(60, now.subtract(const Duration(days: 3))),
        _metric(62, now.subtract(const Duration(days: 6))),
        // outside the 7-day window
        _metric(100, now.subtract(const Duration(days: 10))),
      ];

      final stats = calculator.windowStats(metrics, now: now, windowDays: 7);

      expect(stats.sampleCount, 3);
      expect(stats.average, closeTo((58 + 60 + 62) / 3, 0.0001));
    });

    test('30-day window includes points the 7-day window excludes', () {
      final metrics = [
        _metric(58, now.subtract(const Duration(days: 1))),
        _metric(70, now.subtract(const Duration(days: 20))),
      ];

      final stats30 = calculator.windowStats(metrics, now: now, windowDays: 30);
      final stats7 = calculator.windowStats(metrics, now: now, windowDays: 7);

      expect(stats30.sampleCount, 2);
      expect(stats7.sampleCount, 1);
      expect(stats30.average, closeTo((58 + 70) / 2, 0.0001));
    });

    test('reports zero sample count and average for an empty window', () {
      final stats = calculator.windowStats(const [], now: now, windowDays: 30);
      expect(stats.hasData, isFalse);
      expect(stats.average, 0);
    });
  });

  group('trend', () {
    test('classifies a clear rise as increasing', () {
      final metrics = [
        for (var i = 13; i >= 7; i--) _metric(50, now.subtract(Duration(days: i))), // earlier half
        for (var i = 6; i >= 0; i--) _metric(65, now.subtract(Duration(days: i))), // later half
      ];
      expect(calculator.trend(metrics, now: now, windowDays: 14), TrendDirection.increasing);
    });

    test('classifies a clear fall as decreasing', () {
      final metrics = [
        for (var i = 13; i >= 7; i--) _metric(70, now.subtract(Duration(days: i))),
        for (var i = 6; i >= 0; i--) _metric(55, now.subtract(Duration(days: i))),
      ];
      expect(calculator.trend(metrics, now: now, windowDays: 14), TrendDirection.decreasing);
    });

    test('classifies a small fluctuation as stable', () {
      final metrics = [
        for (var i = 13; i >= 7; i--) _metric(60, now.subtract(Duration(days: i))),
        for (var i = 6; i >= 0; i--) _metric(60.5, now.subtract(Duration(days: i))),
      ];
      expect(calculator.trend(metrics, now: now, windowDays: 14), TrendDirection.stable);
    });

    test('classifies as stable when one half has no data', () {
      final metrics = [_metric(60, now.subtract(const Duration(days: 1)))];
      expect(calculator.trend(metrics, now: now, windowDays: 14), TrendDirection.stable);
    });
  });

  group('percentChange', () {
    test('computes a positive percent change', () {
      expect(calculator.percentChange(current: 66, baseline: 60), closeTo(10.0, 0.0001));
    });

    test('computes a negative percent change', () {
      expect(calculator.percentChange(current: 54, baseline: 60), closeTo(-10.0, 0.0001));
    });

    test('returns null when baseline is zero', () {
      expect(calculator.percentChange(current: 10, baseline: 0), isNull);
    });
  });

  group('computeBaseline', () {
    test('bundles 7/30/90-day windows, trend, and %-change vs 30d baseline', () {
      final metrics = [
        for (var i = 89; i >= 0; i--) _metric(60, now.subtract(Duration(days: i))),
      ];

      final baseline = calculator.computeBaseline(metrics, metricType: 'resting_heart_rate', todayValue: 66, now: now);

      expect(baseline.window7d.average, closeTo(60, 0.01));
      expect(baseline.window30d.average, closeTo(60, 0.01));
      expect(baseline.window90d.average, closeTo(60, 0.01));
      expect(baseline.percentChangeVs30d, closeTo(10.0, 0.01));
    });
  });
}
