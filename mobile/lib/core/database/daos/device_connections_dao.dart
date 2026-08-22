import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../app_database.dart';
import '../tables/device_connections_table.dart';

part 'device_connections_dao.g.dart';

@DriftAccessor(tables: [DeviceConnections])
class DeviceConnectionsDao extends DatabaseAccessor<AppDatabase> with _$DeviceConnectionsDaoMixin {
  DeviceConnectionsDao(super.db);

  Future<void> upsertStatus({
    required String userId,
    required String provider,
    required String status,
    DateTime? lastSyncAt,
    String? lastError,
  }) async {
    final existing = await (select(deviceConnections)
          ..where((t) => t.userId.equals(userId) & t.provider.equals(provider)))
        .getSingleOrNull();
    if (existing == null) {
      await into(deviceConnections).insert(DeviceConnectionsCompanion.insert(
        id: const Uuid().v4(),
        userId: userId,
        provider: provider,
        status: status,
        lastSyncAt: Value(lastSyncAt),
        lastError: Value(lastError),
      ));
    } else {
      await (update(deviceConnections)..where((t) => t.id.equals(existing.id))).write(
        DeviceConnectionsCompanion(
          status: Value(status),
          lastSyncAt: Value(lastSyncAt ?? existing.lastSyncAt),
          lastError: Value(lastError),
        ),
      );
    }
  }

  Future<DeviceConnection?> getConnection({required String userId, required String provider}) {
    return (select(deviceConnections)
          ..where((t) => t.userId.equals(userId) & t.provider.equals(provider)))
        .getSingleOrNull();
  }

  Stream<List<DeviceConnection>> watchConnections(String userId) {
    return (select(deviceConnections)..where((t) => t.userId.equals(userId))).watch();
  }
}
