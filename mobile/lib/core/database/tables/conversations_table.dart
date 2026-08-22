import 'package:drift/drift.dart';

/// DATABASE_SCHEMA.md §conversations.
class Conversations extends Table {
  TextColumn get id => text()(); // uuid
  TextColumn get userId => text().named('user_id')();
  TextColumn get title => text().nullable()(); // derived from first message
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  @override
  Set<Column> get primaryKey => {id};
}
