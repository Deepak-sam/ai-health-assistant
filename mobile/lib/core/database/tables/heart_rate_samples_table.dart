import 'package:drift/drift.dart';

/// DATABASE_SCHEMA.md §heart_rate_samples — high-frequency raw samples, kept
/// separate from `health_metrics` to avoid bloating the generic table.
///
/// Index per DATABASE_SCHEMA.md: (user_id, timestamp).
@TableIndex(name: 'idx_heart_rate_samples_user_time', columns: {#userId, #timestamp})
class HeartRateSamples extends Table {
  TextColumn get id => text()(); // uuid
  TextColumn get userId => text().named('user_id')();
  DateTimeColumn get timestamp => dateTime()();
  IntColumn get bpm => integer()();
  TextColumn get context => text().nullable()(); // e.g. 'resting', 'activity'

  @override
  Set<Column> get primaryKey => {id};
}
