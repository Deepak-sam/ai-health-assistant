import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/ai_insights_table.dart';

part 'ai_insights_dao.g.dart';

@DriftAccessor(tables: [AiInsights])
class AiInsightsDao extends DatabaseAccessor<AppDatabase> with _$AiInsightsDaoMixin {
  AiInsightsDao(super.db);

  /// Inserts the insight unless [AiInsight.dedupKey] already exists for this
  /// user, so the same pattern doesn't resurface noisily
  /// (DATABASE_SCHEMA.md §ai_insights).
  Future<void> insertIfNew(AiInsightsCompanion insight) async {
    final key = insight.dedupKey.value;
    final userId = insight.userId.value;
    final existing = await (select(aiInsights)
          ..where((t) => t.userId.equals(userId) & t.dedupKey.equals(key)))
        .getSingleOrNull();
    if (existing == null) {
      await into(aiInsights).insert(insight);
    }
  }

  Future<List<AiInsight>> getActiveInsights(String userId) {
    return (select(aiInsights)
          ..where((t) => t.userId.equals(userId) & t.dismissed.equals(false))
          ..orderBy([(t) => OrderingTerm.desc(t.surfacedAt)]))
        .get();
  }

  Stream<List<AiInsight>> watchActiveInsights(String userId) {
    return (select(aiInsights)
          ..where((t) => t.userId.equals(userId) & t.dismissed.equals(false))
          ..orderBy([(t) => OrderingTerm.desc(t.surfacedAt)]))
        .watch();
  }

  Future<void> dismiss({required String userId, required String id}) {
    return (update(aiInsights)..where((t) => t.userId.equals(userId) & t.id.equals(id)))
        .write(const AiInsightsCompanion(dismissed: Value(true)));
  }
}
