import 'package:drift/drift.dart';

/// DATABASE_SCHEMA.md §activities.
class Activities extends Table {
  TextColumn get id => text()(); // uuid
  TextColumn get userId => text().named('user_id')();
  TextColumn get provider => text()();
  TextColumn get activityType => text().named('activity_type')(); // 'run' | 'ride' | 'strength' | ...
  DateTimeColumn get startTime => dateTime().named('start_time')();
  IntColumn get durationMin => integer().named('duration_min')();
  RealColumn get distanceM => real().named('distance_m').nullable()();
  IntColumn get calories => integer().nullable()();
  RealColumn get avgHeartRate => real().named('avg_heart_rate').nullable()();
  RealColumn get maxHeartRate => real().named('max_heart_rate').nullable()();
  RealColumn get trainingLoad => real().named('training_load').nullable()();
  TextColumn get metadataJson => text().named('metadata_json').nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
