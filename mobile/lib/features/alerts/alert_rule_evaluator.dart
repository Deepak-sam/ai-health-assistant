import '../health/baseline_calculator.dart';
import '../health/models/health_models.dart' as domain;

/// Plain Dart mirror of the `condition` JSON schema in ARCHITECTURE.md §10.
class AlertConditionSpec {
  const AlertConditionSpec({
    required this.type,
    required this.operator,
    this.threshold,
    this.baselineWindowDays,
    this.baselineMultiplier,
    this.consecutiveCount,
  });

  factory AlertConditionSpec.fromJson(Map<String, dynamic> json) => AlertConditionSpec(
        type: json['type'] as String,
        operator: json['operator'] as String,
        threshold: (json['threshold'] as num?)?.toDouble(),
        baselineWindowDays: json['baseline_window_days'] as int?,
        baselineMultiplier: (json['baseline_multiplier'] as num?)?.toDouble(),
        consecutiveCount: json['consecutive_count'] as int?,
      );

  final String type; // 'threshold' | 'baseline_relative' | 'consecutive_day'
  final String operator; // '>' | '<' | '>=' | '<='
  final double? threshold;
  final int? baselineWindowDays;
  final double? baselineMultiplier;
  final int? consecutiveCount;
}

class AlertRuleSpec {
  const AlertRuleSpec({required this.metricType, required this.condition, required this.window});

  final String metricType;
  final AlertConditionSpec condition;
  final String window; // 'daily' | 'rolling'
}

class AlertEvaluationResult {
  const AlertEvaluationResult({required this.fired, this.triggeringValue, this.message});

  final bool fired;
  final double? triggeringValue;
  final String? message;

  static const notFired = AlertEvaluationResult(fired: false);
}

/// Deterministic, pure-Dart evaluation of a compiled `AlertRule` against a
/// local metric series. **No LLM call, no network** — ARCHITECTURE.md §10:
/// "Evaluate (deterministic, always) ... no LLM call." The LLM only
/// compiles natural language to this structured rule once, at creation
/// time (`POST /alerts/compile`); this class runs on every sync/timer tick.
///
/// [series] is expected to be one value per calendar day, ascending by
/// timestamp (e.g. derived from `daily_health_summary`), matching how
/// `ChatContextBuilder`/`InsightGenerator` build their series too.
class AlertRuleEvaluator {
  const AlertRuleEvaluator({this.calculator = const BaselineCalculator()});

  final BaselineCalculator calculator;

  AlertEvaluationResult evaluate(AlertRuleSpec rule, List<domain.HealthMetric> series, {DateTime? now}) {
    if (series.isEmpty) return AlertEvaluationResult.notFired;
    final effectiveNow = now ?? DateTime.now();
    final sorted = [...series]..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    switch (rule.condition.type) {
      case 'threshold':
        return _evaluateThreshold(rule, sorted);
      case 'baseline_relative':
        return _evaluateBaselineRelative(rule, sorted, effectiveNow);
      case 'consecutive_day':
        return _evaluateConsecutiveDay(rule, sorted);
      default:
        return AlertEvaluationResult.notFired;
    }
  }

  AlertEvaluationResult _evaluateThreshold(AlertRuleSpec rule, List<domain.HealthMetric> sorted) {
    final threshold = rule.condition.threshold;
    if (threshold == null) return AlertEvaluationResult.notFired;
    final latest = sorted.last.value;
    if (!_compare(latest, rule.condition.operator, threshold)) return AlertEvaluationResult.notFired;
    return AlertEvaluationResult(
      fired: true,
      triggeringValue: latest,
      message: 'Your ${_label(rule.metricType)} is ${_operatorPhrase(rule.condition.operator)} '
          '${_formatValue(threshold)} today (currently ${_formatValue(latest)}).',
    );
  }

  AlertEvaluationResult _evaluateBaselineRelative(AlertRuleSpec rule, List<domain.HealthMetric> sorted, DateTime now) {
    final windowDays = rule.condition.baselineWindowDays ?? 30;
    final multiplier = rule.condition.baselineMultiplier ?? 1.0;
    final consecutiveCount = rule.condition.consecutiveCount ?? 1;

    // Baseline computed once over the trailing window (see class doc: this
    // is a documented Phase 1 simplification — it does not exclude the
    // days under test from the baseline window).
    final baseline = calculator.windowStats(sorted, now: now, windowDays: windowDays);
    if (!baseline.hasData) return AlertEvaluationResult.notFired;
    final effectiveThreshold = baseline.average * multiplier;

    final recentDays = _lastNValues(sorted, consecutiveCount);
    if (recentDays.length < consecutiveCount) return AlertEvaluationResult.notFired;

    final allMatch = recentDays.every((v) => _compare(v, rule.condition.operator, effectiveThreshold));
    if (!allMatch) return AlertEvaluationResult.notFired;

    return AlertEvaluationResult(
      fired: true,
      triggeringValue: recentDays.last,
      message: 'Your ${_label(rule.metricType)} has been ${_operatorPhrase(rule.condition.operator)} '
          '${(multiplier > 1 ? '${((multiplier - 1) * 100).round()}% above' : '${((1 - multiplier) * 100).round()}% below')} '
          'your $windowDays-day average for $consecutiveCount consecutive day${consecutiveCount == 1 ? '' : 's'}.',
    );
  }

  AlertEvaluationResult _evaluateConsecutiveDay(AlertRuleSpec rule, List<domain.HealthMetric> sorted) {
    final threshold = rule.condition.threshold;
    final consecutiveCount = rule.condition.consecutiveCount ?? 1;
    if (threshold == null) return AlertEvaluationResult.notFired;

    final recentDays = _lastNValues(sorted, consecutiveCount);
    if (recentDays.length < consecutiveCount) return AlertEvaluationResult.notFired;

    final allMatch = recentDays.every((v) => _compare(v, rule.condition.operator, threshold));
    if (!allMatch) return AlertEvaluationResult.notFired;

    return AlertEvaluationResult(
      fired: true,
      triggeringValue: recentDays.last,
      message: 'Your ${_label(rule.metricType)} has been ${_operatorPhrase(rule.condition.operator)} '
          '${_formatValue(threshold)} for $consecutiveCount consecutive day${consecutiveCount == 1 ? '' : 's'}.',
    );
  }

  List<double> _lastNValues(List<domain.HealthMetric> sorted, int n) {
    if (sorted.length < n) return sorted.map((m) => m.value).toList();
    return sorted.sublist(sorted.length - n).map((m) => m.value).toList();
  }

  bool _compare(double value, String operator, double threshold) {
    switch (operator) {
      case '>':
        return value > threshold;
      case '<':
        return value < threshold;
      case '>=':
        return value >= threshold;
      case '<=':
        return value <= threshold;
      default:
        return false;
    }
  }

  String _operatorPhrase(String operator) {
    switch (operator) {
      case '>':
        return 'above';
      case '<':
        return 'below';
      case '>=':
        return 'at or above';
      case '<=':
        return 'at or below';
      default:
        return operator;
    }
  }

  String _label(String metricType) => metricType.replaceAll('_', ' ');

  String _formatValue(double value) => value == value.roundToDouble() ? value.round().toString() : value.toStringAsFixed(1);
}
