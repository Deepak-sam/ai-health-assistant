import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
// `sqlite3_flutter_libs` isn't imported here — being listed as a pubspec
// dependency is sufficient for Flutter's plugin system to bundle the native
// sqlite3 binary on Android/iOS; no Dart-level API from it is needed.

import 'daos/ai_insights_dao.dart';
import 'daos/alert_rules_dao.dart';
import 'daos/conversations_dao.dart';
import 'daos/device_connections_dao.dart';
import 'daos/health_metrics_dao.dart';
import 'daos/nutrition_entries_dao.dart';
import 'daos/settings_dao.dart';
import 'daos/sync_state_dao.dart';
import 'daos/users_dao.dart';
import 'tables/activities_table.dart';
import 'tables/ai_insights_table.dart';
import 'tables/alert_events_table.dart';
import 'tables/alert_rules_table.dart';
import 'tables/conversations_table.dart';
import 'tables/daily_health_summary_table.dart';
import 'tables/device_connections_table.dart';
import 'tables/health_metrics_table.dart';
import 'tables/heart_rate_samples_table.dart';
import 'tables/messages_table.dart';
import 'tables/nutrition_entries_table.dart';
import 'tables/settings_table.dart';
import 'tables/sleep_sessions_table.dart';
import 'tables/sync_state_table.dart';
import 'tables/users_table.dart';

part 'app_database.g.dart';

/// The on-device SQLite database — source of truth for this device's user
/// (ARCHITECTURE.md §9). Mirrors DATABASE_SCHEMA.md verbatim; do not add
/// columns/tables here without updating that doc first.
@DriftDatabase(
  tables: [
    Users,
    HealthMetrics,
    DailyHealthSummaries,
    SleepSessions,
    HeartRateSamples,
    Activities,
    NutritionEntries,
    Conversations,
    Messages,
    AlertRules,
    AlertEvents,
    DeviceConnections,
    AiInsights,
    SyncStates,
    Settings,
  ],
  daos: [
    UsersDao,
    HealthMetricsDao,
    NutritionEntriesDao,
    ConversationsDao,
    AlertRulesDao,
    DeviceConnectionsDao,
    AiInsightsDao,
    SyncStateDao,
    SettingsDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        // Phase 2+: add onUpgrade steps here as schemaVersion increments.
        // Never destructively drop tables containing user health data.
      );

  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'family_health.sqlite'));
      return NativeDatabase.createInBackground(file);
    });
  }
}

/// Single shared database instance for the app's lifetime.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
