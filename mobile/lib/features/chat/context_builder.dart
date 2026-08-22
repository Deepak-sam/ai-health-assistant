import '../../core/database/app_database.dart' as db;
import '../../shared/models/chat_models.dart';
import '../../shared/repositories/health_repository.dart';
import '../health/baseline_calculator.dart';
import '../health/models/health_models.dart' as domain;

/// Builds the `context` bundle for `POST /chat` (API_SPEC.md) entirely from
/// local Drift data + [BaselineCalculator] — the backend performs no
/// additional DB lookups and computes no statistics (hard constraint #3).
///
/// `daily_health_summary` (DATABASE_SCHEMA.md: "pre-aggregated per-day
/// rollup... for fast chat/chart queries") is the source for both "today"
/// values and the baseline series — reading 90 days of one row/day is far
/// cheaper than re-scanning `health_metrics`.
class ChatContextBuilder {
  ChatContextBuilder(this._healthRepository);

  final HealthRepository _healthRepository;
  final BaselineCalculator _calculator = const BaselineCalculator();

  /// Field extractors: DailyHealthSummary column -> (unit, value getter).
  /// Keys match the JSON field names used in the API_SPEC.md `/chat`
  /// example context (`resting_heart_rate`, `sleep_duration_min`,
  /// `hrv_ms`), extended with a few more of the same table's columns.
  static final Map<String, double? Function(db.DailyHealthSummary)> _fields = {
    'resting_heart_rate': (s) => s.restingHeartRate,
    'sleep_duration_min': (s) => s.sleepDurationMin?.toDouble(),
    'hrv_ms': (s) => s.hrvMs,
    'steps': (s) => s.steps?.toDouble(),
    'calories_active': (s) => s.caloriesActive?.toDouble(),
    'weight_kg': (s) => s.weightKg,
  };

  Future<ChatContext> build({required String userId, int lookbackDays = 90}) async {
    final range = domain.DateRange.lastDays(lookbackDays);
    final summaries = await _healthRepository.getDailySummaries(userId: userId, range: range);
    if (summaries.isEmpty) {
      return const ChatContext();
    }

    final today = summaries.last;
    final metrics = <String, ChatMetricContext>{};

    for (final entry in _fields.entries) {
      final fieldName = entry.key;
      final getter = entry.value;
      final series = summaries
          .where((s) => getter(s) != null)
          .map((s) => domain.HealthMetric(
                metricType: fieldName,
                value: getter(s)!,
                unit: '',
                timestamp: s.date,
              ))
          .toList();
      if (series.isEmpty) continue;

      final todayValue = getter(today);
      final baseline = _calculator.computeBaseline(series, metricType: fieldName, todayValue: todayValue);

      metrics[fieldName] = ChatMetricContext(
        today: todayValue,
        baseline30d: baseline.window30d.hasData ? baseline.window30d.average : null,
        stddev30d: baseline.window30d.hasData ? baseline.window30d.stddev : null,
      );
    }

    final activities = await _healthRepository.getActivities(
      userId: userId,
      range: domain.DateRange.lastDays(7),
    );
    final now = DateTime.now();
    final recentActivities = activities
        .take(5)
        .map((a) => RecentActivityContext(
              type: a.activityType,
              daysAgo: now.difference(a.startTime).inDays,
              durationMin: a.durationMin,
            ))
        .toList();

    return ChatContext(metrics: metrics, recentActivities: recentActivities);
  }

  /// A short, deterministic rolling summary of the conversation so far —
  /// no LLM call (that would defeat the purpose of a *cheap*, predictable
  /// summary and isn't needed for Phase 1's short conversations). Just the
  /// most recent user turns, condensed.
  String buildConversationSummary(List<db.Message> priorMessages) {
    final userTurns = priorMessages.where((m) => m.role == 'user').map((m) => m.content).toList();
    if (userTurns.isEmpty) return '';
    final recent = userTurns.length > 3 ? userTurns.sublist(userTurns.length - 3) : userTurns;
    return 'User has recently asked about: ${recent.join('; ')}';
  }
}
