import 'package:drift/drift.dart';

/// DATABASE_SCHEMA.md §health_metrics — hybrid EAV table, one row per data
/// point, generic across metric types.
///
/// `metric_type` enum (validated at the app layer, stored as text so Drift
/// migrations never need an enum ALTER): heart_rate, resting_heart_rate,
/// hrv, steps, sleep_duration, sleep_score, calories_active, calories_total,
/// distance, stress, body_battery, weight, vo2_max, blood_oxygen,
/// active_minutes.
///
/// Indexes per DATABASE_SCHEMA.md: (user_id, metric_type, timestamp) and
/// (user_id, timestamp).
@TableIndex(name: 'idx_health_metrics_user_type_time', columns: {#userId, #metricType, #timestamp})
@TableIndex(name: 'idx_health_metrics_user_time', columns: {#userId, #timestamp})
class HealthMetrics extends Table {
  TextColumn get id => text()(); // uuid
  TextColumn get userId => text().named('user_id')();
  TextColumn get provider => text()(); // 'garmin' | 'health_connect' | 'manual'
  TextColumn get metricType => text().named('metric_type')();
  RealColumn get value => real()();
  TextColumn get unit => text()();
  DateTimeColumn get timestamp => dateTime()();
  TextColumn get metadataJson => text().named('metadata_json').nullable()();
  DateTimeColumn get createdAt => dateTime().named('created_at')();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [];
}
