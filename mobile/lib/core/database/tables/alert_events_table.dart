import 'package:drift/drift.dart';

/// DATABASE_SCHEMA.md §alert_events.
class AlertEvents extends Table {
  TextColumn get id => text()(); // uuid
  TextColumn get alertRuleId => text().named('alert_rule_id')();
  TextColumn get userId => text().named('user_id')();
  DateTimeColumn get triggeredAt => dateTime().named('triggered_at')();
  TextColumn get message => text()();
  RealColumn get metricValue => real().named('metric_value')();
  BoolColumn get acknowledged => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
