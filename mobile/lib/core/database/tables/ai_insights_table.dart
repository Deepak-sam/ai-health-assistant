import 'package:drift/drift.dart';

/// DATABASE_SCHEMA.md §ai_insights — cached, deduplicated insight strings.
/// Despite the table name (kept verbatim from the schema doc), Phase 1
/// insights are generated deterministically on-device
/// (features/insights/insight_generator.dart) — no LLM call.
class AiInsights extends Table {
  TextColumn get id => text()(); // uuid
  TextColumn get userId => text().named('user_id')();
  TextColumn get insightText => text().named('insight_text')();
  TextColumn get category => text()(); // 'sleep' | 'activity' | 'recovery' | 'nutrition' | 'trend'
  TextColumn get dedupKey => text().named('dedup_key')(); // stable hash
  DateTimeColumn get surfacedAt => dateTime().named('surfaced_at')();
  BoolColumn get dismissed => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {userId, dedupKey},
      ];
}
