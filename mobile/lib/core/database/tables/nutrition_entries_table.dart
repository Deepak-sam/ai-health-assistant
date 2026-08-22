import 'package:drift/drift.dart';

/// DATABASE_SCHEMA.md §nutrition_entries — structured meal data only, never
/// the source photo or a photo reference (ARCHITECTURE.md §15).
class NutritionEntries extends Table {
  TextColumn get id => text()(); // uuid
  TextColumn get userId => text().named('user_id')();
  DateTimeColumn get loggedAt => dateTime().named('logged_at')();
  TextColumn get mealName => text().named('meal_name')();
  TextColumn get source => text()(); // 'photo' | 'text' | 'manual'
  // array of {name, estimated_grams, calories, protein_g, carbs_g, fat_g}
  TextColumn get itemsJson => text().named('items_json')();
  RealColumn get totalCalories => real().named('total_calories')();
  RealColumn get proteinG => real().named('protein_g')();
  RealColumn get carbsG => real().named('carbs_g')();
  RealColumn get fatG => real().named('fat_g')();
  RealColumn get fiberG => real().named('fiber_g').nullable()();
  RealColumn get confidence => real().nullable()(); // 0.0-1.0, only when source == photo
  BoolColumn get confirmed => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
