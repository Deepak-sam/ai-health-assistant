import 'package:drift/drift.dart';

/// DATABASE_SCHEMA.md §sync_state — last successful sync cursor per
/// provider, for incremental sync.
class SyncStates extends Table {
  TextColumn get id => text()(); // uuid
  TextColumn get userId => text().named('user_id')();
  TextColumn get provider => text()();
  TextColumn get lastCursor => text().named('last_cursor').nullable()();
  DateTimeColumn get lastSyncedAt => dateTime().named('last_synced_at').nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {userId, provider},
      ];
}
