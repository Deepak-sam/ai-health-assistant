import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/nutrition_entries_table.dart';

part 'nutrition_entries_dao.g.dart';

@DriftAccessor(tables: [NutritionEntries])
class NutritionEntriesDao extends DatabaseAccessor<AppDatabase> with _$NutritionEntriesDaoMixin {
  NutritionEntriesDao(super.db);

  Future<String> insertEntry(NutritionEntriesCompanion entry) async {
    await into(nutritionEntries).insert(entry);
    return entry.id.value;
  }

  Future<bool> updateEntry(NutritionEntry entry) => update(nutritionEntries).replace(entry);

  Future<void> deleteEntry({required String userId, required String id}) {
    return (delete(nutritionEntries)..where((t) => t.userId.equals(userId) & t.id.equals(id))).go();
  }

  Future<List<NutritionEntry>> getEntriesForDay({
    required String userId,
    required DateTime dayStart,
    required DateTime dayEnd,
  }) {
    return (select(nutritionEntries)
          ..where((t) =>
              t.userId.equals(userId) &
              t.loggedAt.isBiggerOrEqualValue(dayStart) &
              t.loggedAt.isSmallerThanValue(dayEnd))
          ..orderBy([(t) => OrderingTerm.desc(t.loggedAt)]))
        .get();
  }

  Stream<List<NutritionEntry>> watchEntriesForDay({
    required String userId,
    required DateTime dayStart,
    required DateTime dayEnd,
  }) {
    return (select(nutritionEntries)
          ..where((t) =>
              t.userId.equals(userId) &
              t.loggedAt.isBiggerOrEqualValue(dayStart) &
              t.loggedAt.isSmallerThanValue(dayEnd))
          ..orderBy([(t) => OrderingTerm.desc(t.loggedAt)]))
        .watch();
  }

  Future<List<NutritionEntry>> getEntriesInRange({
    required String userId,
    required DateTime from,
    required DateTime to,
  }) {
    return (select(nutritionEntries)
          ..where((t) =>
              t.userId.equals(userId) &
              t.loggedAt.isBiggerOrEqualValue(from) &
              t.loggedAt.isSmallerOrEqualValue(to))
          ..orderBy([(t) => OrderingTerm.desc(t.loggedAt)]))
        .get();
  }
}
