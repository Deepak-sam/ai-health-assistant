import 'package:flutter/material.dart';

import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../models/nutrition_models.dart';

/// Shows a logged/estimated meal's calories and macros — used both inline
/// in chat (when a message carries a nutrition `ChatCard`) and on the
/// nutrition confirm/edit screen.
class NutritionCard extends StatelessWidget {
  const NutritionCard({super.key, required this.result, this.confidenceVisible = true});

  final NutritionResult result;
  final bool confidenceVisible;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(child: Text(result.mealName, style: AppTextStyles.title.copyWith(color: theme.colorScheme.onSurface))),
              if (confidenceVisible && result.confidence != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondary,
                    borderRadius: BorderRadius.circular(AppTheme.chipRadius),
                  ),
                  child: Text(
                    '${(result.confidence! * 100).round()}% confident',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Macro(label: 'kcal', value: result.totalCalories.round().toString()),
              _Macro(label: 'protein', value: '${result.proteinG.round()}g'),
              _Macro(label: 'carbs', value: '${result.carbsG.round()}g'),
              _Macro(label: 'fat', value: '${result.fatG.round()}g'),
            ],
          ),
          if (result.items.isNotEmpty) ...[
            const SizedBox(height: 12),
            Divider(color: theme.dividerColor, height: 1),
            const SizedBox(height: 10),
            ...result.items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Expanded(child: Text('${item.name} (${item.estimatedGrams.round()}g)', style: theme.textTheme.bodyMedium)),
                      Text('${item.calories.round()} kcal', style: theme.textTheme.bodySmall),
                    ],
                  ),
                )),
          ],
          if (result.clarifyingQuestion != null) ...[
            const SizedBox(height: 8),
            Text(result.clarifyingQuestion!, style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
          ],
        ],
      ),
    );
  }
}

class _Macro extends StatelessWidget {
  const _Macro({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: AppTextStyles.bodyMedium.copyWith(color: Theme.of(context).colorScheme.onSurface)),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
