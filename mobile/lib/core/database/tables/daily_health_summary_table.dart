import 'package:drift/drift.dart';

/// DATABASE_SCHEMA.md §daily_health_summary — pre-aggregated per-day rollup
/// for fast chat/chart reads without re-scanning `health_metrics`.
class DailyHealthSummaries extends Table {
  TextColumn get id => text()(); // uuid
  TextColumn get userId => text().named('user_id')();
  DateTimeColumn get date => dateTime()(); // stored at midnight UTC for the day
  IntColumn get steps => integer().nullable()();
  IntColumn get caloriesActive => integer().named('calories_active').nullable()();
  IntColumn get caloriesTotal => integer().named('calories_total').nullable()();
  IntColumn get activeMinutes => integer().named('active_minutes').nullable()();
  RealColumn get distanceM => real().named('distance_m').nullable()();
  RealColumn get restingHeartRate => real().named('resting_heart_rate').nullable()();
  RealColumn get hrvMs => real().named('hrv_ms').nullable()();
  IntColumn get sleepDurationMin => integer().named('sleep_duration_min').nullable()();
  IntColumn get sleepScore => integer().named('sleep_score').nullable()();
  RealColumn get weightKg => real().named('weight_kg').nullable()();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {userId, date},
      ];
}
