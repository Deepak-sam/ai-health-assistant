import 'package:drift/drift.dart';

/// DATABASE_SCHEMA.md §users — local record of the signed-in family member.
class Users extends Table {
  TextColumn get id => text()(); // uuid
  TextColumn get email => text().unique()();
  TextColumn get displayName => text().named('display_name')();
  TextColumn get role => text()(); // 'admin' | 'member'
  DateTimeColumn get createdAt => dateTime().named('created_at')();

  @override
  Set<Column> get primaryKey => {id};
}
