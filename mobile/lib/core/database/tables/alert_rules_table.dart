import 'package:drift/drift.dart';

/// DATABASE_SCHEMA.md §alert_rules. `condition_json` mirrors the
/// `AlertRule.condition` schema in ARCHITECTURE.md §10 exactly (see
/// shared/models/alert_models.dart for the Dart shape).
class AlertRules extends Table {
  TextColumn get id => text()(); // uuid
  TextColumn get userId => text().named('user_id')();
  TextColumn get metricType => text().named('metric_type')();
  TextColumn get conditionJson => text().named('condition_json')();
  TextColumn get window => text()(); // 'daily' | 'rolling'
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  TextColumn get createdFromText => text().named('created_from_text')();
  DateTimeColumn get createdAt => dateTime().named('created_at')();

  @override
  Set<Column> get primaryKey => {id};
}
