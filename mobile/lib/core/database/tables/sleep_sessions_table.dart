import 'package:drift/drift.dart';

/// DATABASE_SCHEMA.md §sleep_sessions.
class SleepSessions extends Table {
  TextColumn get id => text()(); // uuid
  TextColumn get userId => text().named('user_id')();
  TextColumn get provider => text()();
  DateTimeColumn get startTime => dateTime().named('start_time')();
  DateTimeColumn get endTime => dateTime().named('end_time')();
  IntColumn get durationMin => integer().named('duration_min')();
  IntColumn get sleepScore => integer().named('sleep_score').nullable()();
  // e.g. {"deep":90,"light":240,"rem":80,"awake":15} (minutes)
  TextColumn get stagesJson => text().named('stages_json').nullable()();
  RealColumn get restingHeartRate => real().named('resting_heart_rate').nullable()();
  RealColumn get hrvMs => real().named('hrv_ms').nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
