import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/users_table.dart';

part 'users_dao.g.dart';

@DriftAccessor(tables: [Users])
class UsersDao extends DatabaseAccessor<AppDatabase> with _$UsersDaoMixin {
  UsersDao(super.db);

  Future<void> upsertUser(UsersCompanion user) => into(users).insertOnConflictUpdate(user);

  Future<User?> getUser(String id) => (select(users)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<User?> getUserByEmail(String email) =>
      (select(users)..where((t) => t.email.equals(email))).getSingleOrNull();

  Stream<User?> watchUser(String id) =>
      (select(users)..where((t) => t.id.equals(id))).watchSingleOrNull();
}
