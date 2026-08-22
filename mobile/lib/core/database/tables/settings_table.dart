import 'package:drift/drift.dart';

/// DATABASE_SCHEMA.md §settings — key/value app settings (units,
/// notification prefs, alert defaults). Composite PK per the schema doc.
class Settings extends Table {
  TextColumn get userId => text().named('user_id')();
  TextColumn get key => text()();
  TextColumn get value => text()(); // JSON-encoded

  @override
  Set<Column> get primaryKey => {userId, key};
}
