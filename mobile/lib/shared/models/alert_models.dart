/// Mirrors the alert rule schema in ARCHITECTURE.md §10 and the
/// `POST /alerts/compile` request/response shapes in API_SPEC.md.
library alert_models;

/// `condition.type`: threshold | baseline_relative | consecutive_day
class AlertCondition {
  const AlertCondition({
    required this.type,
    required this.operator,
    this.threshold,
    this.baselineWindowDays,
    this.baselineMultiplier,
    this.consecutiveCount,
  });

  factory AlertCondition.fromJson(Map<String, dynamic> json) => AlertCondition(
        type: json['type'] as String,
        operator: json['operator'] as String,
        threshold: (json['threshold'] as num?)?.toDouble(),
        baselineWindowDays: json['baseline_window_days'] as int?,
        baselineMultiplier: (json['baseline_multiplier'] as num?)?.toDouble(),
        consecutiveCount: json['consecutive_count'] as int?,
      );

  final String type;
  final String operator; // '>' | '<' | '>=' | '<='
  final double? threshold;
  final int? baselineWindowDays;
  final double? baselineMultiplier;
  final int? consecutiveCount;

  Map<String, dynamic> toJson() => {
        'type': type,
        'operator': operator,
        if (threshold != null) 'threshold': threshold,
        if (baselineWindowDays != null) 'baseline_window_days': baselineWindowDays,
        if (baselineMultiplier != null) 'baseline_multiplier': baselineMultiplier,
        if (consecutiveCount != null) 'consecutive_count': consecutiveCount,
      };
}

/// The compiled rule shape returned by `/alerts/compile` (metric_type +
/// condition + window — no id/user_id/enabled yet; those are assigned when
/// the client persists it locally into `alert_rules`).
class CompiledAlertRule {
  const CompiledAlertRule({required this.metricType, required this.condition, required this.window});

  factory CompiledAlertRule.fromJson(Map<String, dynamic> json) => CompiledAlertRule(
        metricType: json['metric_type'] as String,
        condition: AlertCondition.fromJson(json['condition'] as Map<String, dynamic>),
        window: json['window'] as String,
      );

  final String metricType;
  final AlertCondition condition;
  final String window; // 'daily' | 'rolling'
}

class AlertCompileResponse {
  const AlertCompileResponse({required this.rule, required this.confirmationText});

  factory AlertCompileResponse.fromJson(Map<String, dynamic> json) => AlertCompileResponse(
        rule: CompiledAlertRule.fromJson(json['rule'] as Map<String, dynamic>),
        confirmationText: json['confirmation_text'] as String,
      );

  final CompiledAlertRule rule;
  final String confirmationText;
}

class AlertCompileRequest {
  const AlertCompileRequest({required this.text});

  final String text;

  Map<String, dynamic> toJson() => {'text': text};
}
