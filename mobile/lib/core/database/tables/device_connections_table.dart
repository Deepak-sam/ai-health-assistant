import 'package:drift/drift.dart';

/// DATABASE_SCHEMA.md §device_connections — non-secret connection status
/// only. OAuth/session tokens live in `flutter_secure_storage`
/// (core/security/secure_token_storage.dart), never in this table.
class DeviceConnections extends Table {
  TextColumn get id => text()(); // uuid
  TextColumn get userId => text().named('user_id')();
  TextColumn get provider => text()(); // 'garmin' | 'health_connect'
  TextColumn get status => text()(); // 'connected' | 'disconnected' | 'error'
  DateTimeColumn get lastSyncAt => dateTime().named('last_sync_at').nullable()();
  TextColumn get lastError => text().named('last_error').nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
