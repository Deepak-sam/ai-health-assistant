import '../../core/database/app_database.dart' as db;
import '../health/baseline_calculator.dart';
import '../health/models/health_models.dart' as domain;

class GeneratedInsight {
  const GeneratedInsight({required this.category, required this.text, required this.dedupKey});

  final String category; // 'sleep' | 'activity' | 'recovery' | 'nutrition' | 'trend'
  final String text;
  final String dedupKey;
}

/// Deterministic, on-device insight generation — explicitly **no LLM call**
/// (ARCHITECTURE.md §1/§42: statistics are computed in Dart; this class
/// applies the same rule to "is this worth mentioning" pattern-matching).
/// Compares this week's vs last week's average for a handful of
/// `daily_health_summary` fields via [BaselineCalculator] and produces a
/// plain-language sentence only when the change clears
/// [noticeableChangePercent].
class InsightGenerator {
  const InsightGenerator({
    this.calculator = const BaselineCalculator(),
    this.noticeableChangePercent = 10.0,
  });

  final BaselineCalculator calculator;
  final double noticeableChangePercent;

  static const _fields = <String, ({String label, String unit, String category, bool higherIsBetter})>{
    'sleep_duration_min': (label: 'sleep', unit: 'min', category: 'sleep', higherIsBetter: true),
    'steps': (label: 'steps', unit: 'steps', category: 'activity', higherIsBetter: true),
    'resting_heart_rate': (label: 'resting heart rate', unit: 'bpm', category: 'recovery', higherIsBetter: false),
  };

  List<GeneratedInsight> generate(List<db.DailyHealthSummary> summaries, {DateTime? now}) {
    final effectiveNow = now ?? DateTime.now();
    final insights = <GeneratedInsight>[];

    for (final entry in _fields.entries) {
      final fieldKey = entry.key;
      final meta = entry.value;
      final series = _seriesFor(summaries, fieldKey);
      if (series.length < 4) continue; // not enough data to say anything meaningful

      final thisWeek = calculator.windowStats(series, now: effectiveNow, windowDays: 7);
      final lastWeek = calculator.windowStats(series, now: effectiveNow.subtract(const Duration(days: 7)), windowDays: 7);
      if (!thisWeek.hasData || !lastWeek.hasData) continue;

      final pctChange = calculator.percentChange(current: thisWeek.average, baseline: lastWeek.average);
      if (pctChange == null || pctChange.abs() < noticeableChangePercent) continue;

      final improving = meta.higherIsBetter ? pctChange > 0 : pctChange < 0;
      final direction = pctChange > 0 ? 'up' : 'down';
      final text = _sentenceFor(
        label: meta.label,
        direction: direction,
        pctChange: pctChange.abs(),
        thisWeekAvg: thisWeek.average,
        unit: meta.unit,
        improving: improving,
      );

      insights.add(GeneratedInsight(
        category: meta.category,
        text: text,
        dedupKey: '${fieldKey}_${_isoWeekKey(effectiveNow)}',
      ));
    }

    return insights;
  }

  List<domain.HealthMetric> _seriesFor(List<db.DailyHealthSummary> summaries, String field) {
    double? valueOf(db.DailyHealthSummary s) {
      switch (field) {
        case 'sleep_duration_min':
          return s.sleepDurationMin?.toDouble();
        case 'steps':
          return s.steps?.toDouble();
        case 'resting_heart_rate':
          return s.restingHeartRate;
        default:
          return null;
      }
    }

    return summaries
        .where((s) => valueOf(s) != null)
        .map((s) => domain.HealthMetric(metricType: field, value: valueOf(s)!, unit: '', timestamp: s.date))
        .toList();
  }

  String _sentenceFor({
    required String label,
    required String direction,
    required double pctChange,
    required double thisWeekAvg,
    required String unit,
    required bool improving,
  }) {
    final rounded = pctChange.round();
    final tone = improving ? 'up from last week' : 'a change from last week worth noting';
    final avgText = unit == 'min' ? '${(thisWeekAvg / 60).toStringAsFixed(1)}h' : thisWeekAvg.round().toString();
    return 'Your average $label is $direction $rounded% this week ($avgText $unit avg) — $tone.';
  }

  String _isoWeekKey(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final daysSinceStart = date.difference(firstDayOfYear).inDays;
    final week = ((daysSinceStart + firstDayOfYear.weekday - 1) / 7).floor();
    return '${date.year}_w$week';
  }
}
