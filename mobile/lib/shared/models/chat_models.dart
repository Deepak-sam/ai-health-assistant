/// Mirrors the `POST /chat` request/response JSON shapes in API_SPEC.md
/// exactly. `ChatContext` is built entirely client-side from local Drift
/// data + `BaselineCalculator` (features/health/baseline_calculator.dart) —
/// the backend performs no additional DB lookups and computes no statistics
/// (hard constraint #3).
library chat_models;

/// One metric's pre-computed context, e.g.:
/// `"resting_heart_rate": {"today": 58, "baseline_30d": 59.2, "stddev_30d": 2.1}`
class ChatMetricContext {
  const ChatMetricContext({this.today, this.baseline30d, this.stddev30d});

  final num? today;
  final num? baseline30d;
  final num? stddev30d;

  Map<String, dynamic> toJson() => {
        if (today != null) 'today': today,
        if (baseline30d != null) 'baseline_30d': baseline30d,
        if (stddev30d != null) 'stddev_30d': stddev30d,
      };
}

/// e.g. `{"type": "run", "days_ago": 1, "duration_min": 40}`
class RecentActivityContext {
  const RecentActivityContext({required this.type, required this.daysAgo, required this.durationMin});

  final String type;
  final int daysAgo;
  final int durationMin;

  Map<String, dynamic> toJson() => {
        'type': type,
        'days_ago': daysAgo,
        'duration_min': durationMin,
      };
}

class ChatContext {
  const ChatContext({this.metrics = const {}, this.recentActivities = const []});

  final Map<String, ChatMetricContext> metrics;
  final List<RecentActivityContext> recentActivities;

  Map<String, dynamic> toJson() => {
        'metrics': {for (final e in metrics.entries) e.key: e.value.toJson()},
        'recent_activities': recentActivities.map((a) => a.toJson()).toList(),
      };
}

class ChatMessageSummary {
  const ChatMessageSummary({required this.role, required this.content});

  factory ChatMessageSummary.fromJson(Map<String, dynamic> json) =>
      ChatMessageSummary(role: json['role'] as String, content: json['content'] as String);

  final String role; // 'user' | 'assistant'
  final String content;

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

class ChatRequest {
  const ChatRequest({
    required this.message,
    required this.context,
    required this.conversationSummary,
    required this.recentMessages,
  });

  final String message;
  final ChatContext context;
  final String conversationSummary;
  final List<ChatMessageSummary> recentMessages;

  Map<String, dynamic> toJson() => {
        'message': message,
        'context': context.toJson(),
        'conversation_summary': conversationSummary,
        'recent_messages': recentMessages.map((m) => m.toJson()).toList(),
      };
}

/// The API_SPEC.md example only shows `"cards": []`; the per-card schema
/// itself isn't pinned down in the spec doc. This is a Phase 1 assumption:
/// a small discriminated shape (`type` + `title` + flat `metrics` map) that
/// `HealthCard`/`NutritionCard` can render generically. Tighten this once
/// the backend team finalizes a card schema.
class ChatCard {
  const ChatCard({required this.type, required this.title, this.subtitle, this.metrics = const {}});

  factory ChatCard.fromJson(Map<String, dynamic> json) => ChatCard(
        type: json['type'] as String? ?? 'generic',
        title: json['title'] as String? ?? '',
        subtitle: json['subtitle'] as String?,
        metrics: (json['metrics'] as Map<String, dynamic>?)?.cast<String, dynamic>() ?? const {},
      );

  final String type; // e.g. 'health_metric' | 'nutrition' | 'generic'
  final String title;
  final String? subtitle;
  final Map<String, dynamic> metrics;
}

class ChatResponse {
  const ChatResponse({
    required this.reply,
    required this.cards,
    required this.suggestedFollowups,
    required this.safetyFlag,
  });

  factory ChatResponse.fromJson(Map<String, dynamic> json) => ChatResponse(
        reply: json['reply'] as String? ?? '',
        cards: (json['cards'] as List<dynamic>? ?? const [])
            .map((c) => ChatCard.fromJson(c as Map<String, dynamic>))
            .toList(),
        suggestedFollowups:
            (json['suggested_followups'] as List<dynamic>? ?? const []).map((e) => e as String).toList(),
        safetyFlag: json['safety_flag'] as String?,
      );

  final String reply;
  final List<ChatCard> cards;
  final List<String> suggestedFollowups;
  /// e.g. "seek_medical_attention" — client renders a distinct,
  /// non-dismissible style per ARCHITECTURE.md §9/§24.
  final String? safetyFlag;
}
