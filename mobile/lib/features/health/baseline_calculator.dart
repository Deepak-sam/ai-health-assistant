import 'dart:math' as math;

import 'models/health_models.dart';

/// ARCHITECTURE.md §1/§9/§42 hard rule: all statistics (averages, stddev,
/// trend, % change, rolling windows) are computed in Dart, never sent to the
/// backend and never computed by the LLM. This class is pure — no network,
/// no database, no Flutter dependency — so it can be unit tested directly
/// (see test/baseline_calculator_test.dart) and reused anywhere a
/// `List<HealthMetric>` is available (chat context builder, insights,
/// charts).
enum TrendDirection { increasing, decreasing, stable }

class BaselineWindowStats {
  const BaselineWindowStats({
    required this.windowDays,
    required this.average,
    required this.stddev,
    required this.sampleCount,
  });

  final int windowDays;
  final double average;
  final double stddev;
  final int sampleCount;

  bool get hasData => sampleCount > 0;
}

class MetricBaseline {
  const MetricBaseline({
    required this.metricType,
    required this.window7d,
    required this.window30d,
    required this.window90d,
    required this.trend,
    this.today,
    this.percentChangeVs30d,
  });

  final String metricType;
  final double? today;
  final BaselineWindowStats window7d;
  final BaselineWindowStats window30d;
  final BaselineWindowStats window90d;
  final TrendDirection trend;
  final double? percentChangeVs30d;
}

class BaselineCalculator {
  const BaselineCalculator({this.stableTrendThresholdPercent = 3.0});

  /// Below this absolute percent change between the earlier/later half of
  /// the trend window, the trend is classified as "stable" rather than
  /// increasing/decreasing (avoids noise from tiny fluctuations).
  final double stableTrendThresholdPercent;

  double average(Iterable<double> values) {
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  /// Sample standard deviation (n-1 denominator). Returns 0 for fewer than
  /// two data points — there's no meaningful spread to report.
  double stddev(Iterable<double> values) {
    if (values.length < 2) return 0;
    final avg = average(values);
    final sumSquaredDiffs = values.map((v) => (v - avg) * (v - avg)).reduce((a, b) => a + b);
    return math.sqrt(sumSquaredDiffs / (values.length - 1));
  }

  List<double> _valuesInWindow(List<HealthMetric> metrics, DateTime now, int windowDays) {
    final start = now.subtract(Duration(days: windowDays));
    return metrics
        .where((m) => !m.timestamp.isBefore(start) && !m.timestamp.isAfter(now))
        .map((m) => m.value)
        .toList();
  }

  BaselineWindowStats windowStats(
    List<HealthMetric> metrics, {
    required DateTime now,
    required int windowDays,
  }) {
    final values = _valuesInWindow(metrics, now, windowDays);
    return BaselineWindowStats(
      windowDays: windowDays,
      average: average(values),
      stddev: stddev(values),
      sampleCount: values.length,
    );
  }

  /// Splits the trailing [windowDays] into two equal halves and compares
  /// their averages. A change smaller than [stableTrendThresholdPercent] of
  /// the earlier half's average counts as "stable". Defaults to a 14-day
  /// window, which is short enough to reflect a recent shift without being
  /// dominated by single-day noise.
  TrendDirection trend(
    List<HealthMetric> metrics, {
    DateTime? now,
    int windowDays = 14,
  }) {
    final effectiveNow = now ?? DateTime.now();
    final start = effectiveNow.subtract(Duration(days: windowDays));
    final mid = effectiveNow.subtract(Duration(days: windowDays ~/ 2));

    final earlier = metrics
        .where((m) => !m.timestamp.isBefore(start) && m.timestamp.isBefore(mid))
        .map((m) => m.value)
        .toList();
    final later = metrics
        .where((m) => !m.timestamp.isBefore(mid) && !m.timestamp.isAfter(effectiveNow))
        .map((m) => m.value)
        .toList();

    if (earlier.isEmpty || later.isEmpty) return TrendDirection.stable;

    final earlierAvg = average(earlier);
    final laterAvg = average(later);
    if (earlierAvg == 0) return TrendDirection.stable;

    final pctChange = (laterAvg - earlierAvg) / earlierAvg.abs() * 100;
    if (pctChange.abs() < stableTrendThresholdPercent) return TrendDirection.stable;
    return pctChange > 0 ? TrendDirection.increasing : TrendDirection.decreasing;
  }

  /// Percent change of [current] relative to [baseline]. Null when
  /// [baseline] is zero (undefined / would divide by zero).
  double? percentChange({required double current, required double baseline}) {
    if (baseline == 0) return null;
    return (current - baseline) / baseline.abs() * 100;
  }

  /// Convenience: computes the full 7/30/90-day + trend + %-change bundle
  /// for one metric type, ready to be dropped into the /chat `context`
  /// payload (see features/chat/context_builder.dart).
  MetricBaseline computeBaseline(
    List<HealthMetric> metrics, {
    required String metricType,
    double? todayValue,
    DateTime? now,
  }) {
    final effectiveNow = now ?? DateTime.now();
    final window7d = windowStats(metrics, now: effectiveNow, windowDays: 7);
    final window30d = windowStats(metrics, now: effectiveNow, windowDays: 30);
    final window90d = windowStats(metrics, now: effectiveNow, windowDays: 90);
    final trendDirection = trend(metrics, now: effectiveNow);
    final pctChange = (todayValue != null && window30d.hasData)
        ? percentChange(current: todayValue, baseline: window30d.average)
        : null;

    return MetricBaseline(
      metricType: metricType,
      today: todayValue,
      window7d: window7d,
      window30d: window30d,
      window90d: window90d,
      trend: trendDirection,
      percentChangeVs30d: pctChange,
    );
  }
}
