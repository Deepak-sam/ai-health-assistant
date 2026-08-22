import 'package:family_health_assistant/features/alerts/alert_rule_evaluator.dart';
import 'package:family_health_assistant/features/health/models/health_models.dart';
import 'package:flutter_test/flutter_test.dart';

HealthMetric _metric(double value, DateTime timestamp) => HealthMetric(
      metricType: 'resting_heart_rate',
      value: value,
      unit: 'bpm',
      timestamp: timestamp,
    );

void main() {
  const evaluator = AlertRuleEvaluator();
  final now = DateTime(2026, 1, 31, 12);

  group('threshold rule', () {
    final rule = const AlertRuleSpec(
      metricType: 'resting_heart_rate',
      condition: AlertConditionSpec(type: 'threshold', operator: '>', threshold: 90),
      window: 'daily',
    );

    test('fires when the latest value exceeds the threshold', () {
      final series = [
        _metric(58, now.subtract(const Duration(days: 1))),
        _metric(95, now), // latest
      ];
      final result = evaluator.evaluate(rule, series, now: now);
      expect(result.fired, isTrue);
      expect(result.triggeringValue, 95);
    });

    test('does not fire when the latest value is at or below the threshold', () {
      final series = [
        _metric(95, now.subtract(const Duration(days: 1))),
        _metric(60, now), // latest, below threshold
      ];
      final result = evaluator.evaluate(rule, series, now: now);
      expect(result.fired, isFalse);
    });

    test('does not fire with no data', () {
      final result = evaluator.evaluate(rule, const [], now: now);
      expect(result.fired, isFalse);
    });
  });

  group('baseline_relative rule', () {
    // "resting heart rate more than 10% above the 30-day average for 2
    // consecutive days" — mirrors the ARCHITECTURE.md §10 example.
    final rule = const AlertRuleSpec(
      metricType: 'resting_heart_rate',
      condition: AlertConditionSpec(
        type: 'baseline_relative',
        operator: '>',
        baselineWindowDays: 30,
        baselineMultiplier: 1.10,
        consecutiveCount: 2,
      ),
      window: 'rolling',
    );

    test('fires when the last N days are all above baseline * multiplier', () {
      final series = [
        for (var i = 29; i >= 2; i--) _metric(60, now.subtract(Duration(days: i))), // steady 30-day baseline ~60
        _metric(70, now.subtract(const Duration(days: 1))), // > 60 * 1.10 = 66
        _metric(72, now), // > 66
      ];
      final result = evaluator.evaluate(rule, series, now: now);
      expect(result.fired, isTrue);
      expect(result.triggeringValue, 72);
    });

    test('does not fire when only one of the last N days breaches', () {
      final series = [
        for (var i = 29; i >= 2; i--) _metric(60, now.subtract(Duration(days: i))),
        _metric(62, now.subtract(const Duration(days: 1))), // below 66 — breaks the streak
        _metric(72, now),
      ];
      final result = evaluator.evaluate(rule, series, now: now);
      expect(result.fired, isFalse);
    });

    test('does not fire when there is no baseline data', () {
      final result = evaluator.evaluate(rule, const [], now: now);
      expect(result.fired, isFalse);
    });
  });

  group('consecutive_day rule', () {
    // "steps below 3000 for 3 consecutive days"
    final rule = const AlertRuleSpec(
      metricType: 'steps',
      condition: AlertConditionSpec(type: 'consecutive_day', operator: '<', threshold: 3000, consecutiveCount: 3),
      window: 'rolling',
    );

    HealthMetric stepsMetric(double value, DateTime timestamp) =>
        HealthMetric(metricType: 'steps', value: value, unit: 'count', timestamp: timestamp);

    test('fires when the threshold is breached on all of the last N days', () {
      final series = [
        stepsMetric(8000, now.subtract(const Duration(days: 5))),
        stepsMetric(2000, now.subtract(const Duration(days: 2))),
        stepsMetric(1500, now.subtract(const Duration(days: 1))),
        stepsMetric(1000, now),
      ];
      final result = evaluator.evaluate(rule, series, now: now);
      expect(result.fired, isTrue);
      expect(result.triggeringValue, 1000);
    });

    test('does not fire when the streak is broken', () {
      final series = [
        stepsMetric(2000, now.subtract(const Duration(days: 2))),
        stepsMetric(5000, now.subtract(const Duration(days: 1))), // breaks the streak
        stepsMetric(1000, now),
      ];
      final result = evaluator.evaluate(rule, series, now: now);
      expect(result.fired, isFalse);
    });

    test('does not fire when there are fewer days than required', () {
      final series = [stepsMetric(1000, now), stepsMetric(1200, now.subtract(const Duration(days: 1)))];
      final result = evaluator.evaluate(rule, series, now: now);
      expect(result.fired, isFalse);
    });
  });
}
