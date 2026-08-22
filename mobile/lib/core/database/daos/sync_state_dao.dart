import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../app_database.dart';
import '../tables/sync_state_table.dart';

part 'sync_state_dao.g.dart';

@DriftAccessor(tables: [SyncStates])
class SyncStateDao extends DatabaseAccessor<AppDatabase> with _$SyncStateDaoMixin {
  SyncStateDao(super.db);

  Future<SyncState?> getState({required String userId, required String provider}) {
    return (select(syncStates)..where((t) => t.userId.equals(userId) & t.provider.equals(provider)))
        .getSingleOrNull();
  }

  Future<void> updateCursor({
    required String userId,
    required String provider,
    String? cursor,
    required DateTime syncedAt,
  }) async {
    final existing = await getState(userId: userId, provider: provider);
    if (existing == null) {
      await into(syncStates).insert(SyncStatesCompanion.insert(
        id: const Uuid().v4(),
        userId: userId,
        provider: provider,
        lastCursor: Value(cursor),
        lastSyncedAt: Value(syncedAt),
      ));
    } else {
      await (update(syncStates)..where((t) => t.id.equals(existing.id))).write(
        SyncStatesCompanion(lastCursor: Value(cursor), lastSyncedAt: Value(syncedAt)),
      );
    }
  }
}
