/// Mirrors `POST /nutrition/photo` and `POST /nutrition/text` request/response
/// shapes in API_SPEC.md.
library nutrition_models;

class NutritionItem {
  const NutritionItem({
    required this.name,
    required this.estimatedGrams,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });

  factory NutritionItem.fromJson(Map<String, dynamic> json) => NutritionItem(
        name: json['name'] as String,
        estimatedGrams: (json['estimated_grams'] as num).toDouble(),
        calories: (json['calories'] as num).toDouble(),
        proteinG: (json['protein_g'] as num).toDouble(),
        carbsG: (json['carbs_g'] as num).toDouble(),
        fatG: (json['fat_g'] as num).toDouble(),
      );

  final String name;
  final double estimatedGrams;
  final double calories;
  final double proteinG;
  final double carbsG;
  final double fatG;

  NutritionItem copyWith({
    String? name,
    double? estimatedGrams,
    double? calories,
    double? proteinG,
    double? carbsG,
    double? fatG,
  }) {
    return NutritionItem(
      name: name ?? this.name,
      estimatedGrams: estimatedGrams ?? this.estimatedGrams,
      calories: calories ?? this.calories,
      proteinG: proteinG ?? this.proteinG,
      carbsG: carbsG ?? this.carbsG,
      fatG: fatG ?? this.fatG,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'estimated_grams': estimatedGrams,
        'calories': calories,
        'protein_g': proteinG,
        'carbs_g': carbsG,
        'fat_g': fatG,
      };
}

class NutritionResult {
  const NutritionResult({
    required this.mealName,
    required this.items,
    required this.totalCalories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    this.confidence,
    this.clarifyingQuestion,
  });

  factory NutritionResult.fromJson(Map<String, dynamic> json) => NutritionResult(
        mealName: json['meal_name'] as String? ?? 'Meal',
        items: (json['items'] as List<dynamic>? ?? const [])
            .map((e) => NutritionItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        totalCalories: (json['total_calories'] as num).toDouble(),
        proteinG: (json['protein_g'] as num).toDouble(),
        carbsG: (json['carbs_g'] as num).toDouble(),
        fatG: (json['fat_g'] as num).toDouble(),
        confidence: (json['confidence'] as num?)?.toDouble(),
        clarifyingQuestion: json['clarifying_question'] as String?,
      );

  final String mealName;
  final List<NutritionItem> items;
  final double totalCalories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double? confidence;
  final String? clarifyingQuestion;

  NutritionResult copyWith({String? mealName, List<NutritionItem>? items}) {
    final newItems = items ?? this.items;
    return NutritionResult(
      mealName: mealName ?? this.mealName,
      items: newItems,
      totalCalories: newItems.fold(0.0, (sum, i) => sum + i.calories),
      proteinG: newItems.fold(0.0, (sum, i) => sum + i.proteinG),
      carbsG: newItems.fold(0.0, (sum, i) => sum + i.carbsG),
      fatG: newItems.fold(0.0, (sum, i) => sum + i.fatG),
      confidence: confidence,
      clarifyingQuestion: clarifyingQuestion,
    );
  }
}

class NutritionTextRequest {
  const NutritionTextRequest({required this.text, this.priorEstimate});

  final String text;
  final Map<String, dynamic>? priorEstimate;

  Map<String, dynamic> toJson() => {'text': text, 'prior_estimate': priorEstimate};
}
