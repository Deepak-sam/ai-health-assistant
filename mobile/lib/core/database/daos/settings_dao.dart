import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/settings_table.dart';

part 'settings_dao.g.dart';

@DriftAccessor(tables: [Settings])
class SettingsDao extends DatabaseAccessor<AppDatabase> with _$SettingsDaoMixin {
  SettingsDao(super.db);

  Future<void> setValue({required String userId, required String key, required String jsonValue}) {
    return into(settings).insertOnConflictUpdate(
      SettingsCompanion.insert(userId: userId, key: key, value: jsonValue),
    );
  }

  Future<String?> getValue({required String userId, required String key}) async {
    final row = await (select(settings)..where((t) => t.userId.equals(userId) & t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Stream<String?> watchValue({required String userId, required String key}) {
    return (select(settings)..where((t) => t.userId.equals(userId) & t.key.equals(key)))
        .watchSingleOrNull()
        .map((row) => row?.value);
  }

  Future<Map<String, String>> getAll(String userId) async {
    final rows = await (select(settings)..where((t) => t.userId.equals(userId))).get();
    return {for (final r in rows) r.key: r.value};
  }
}
