import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/models/nutrition_models.dart';
import '../../shared/repositories/nutrition_repository.dart';
import '../../shared/widgets/nutrition_card.dart';
import '../auth/auth_state.dart';

class NutritionConfirmArgs {
  const NutritionConfirmArgs({required this.result, required this.source});

  final NutritionResult result;
  final String source; // 'photo' | 'text'
}

/// Lets the user confirm or edit the AI's structured estimate before it's
/// saved to `nutrition_entries` (DATABASE_SCHEMA.md: `confirmed` column
/// exists precisely so an unreviewed AI guess is distinguishable from a
/// user-confirmed entry).
class NutritionConfirmScreen extends ConsumerStatefulWidget {
  const NutritionConfirmScreen({super.key, required this.args});

  final NutritionConfirmArgs args;

  @override
  ConsumerState<NutritionConfirmScreen> createState() => _NutritionConfirmScreenState();
}

class _NutritionConfirmScreenState extends ConsumerState<NutritionConfirmScreen> {
  late NutritionResult _result = widget.args.result;
  late final TextEditingController _mealNameController = TextEditingController(text: _result.mealName);
  bool _saving = false;

  @override
  void dispose() {
    _mealNameController.dispose();
    super.dispose();
  }

  void _updateItem(int index, NutritionItem updated) {
    final items = [..._result.items];
    items[index] = updated;
    setState(() => _result = _result.copyWith(items: items));
  }

  void _removeItem(int index) {
    final items = [..._result.items]..removeAt(index);
    setState(() => _result = _result.copyWith(items: items));
  }

  Future<void> _save() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    setState(() => _saving = true);
    final finalResult = _result.copyWith(mealName: _mealNameController.text.trim());
    await ref.read(nutritionRepositoryProvider).saveConfirmedEntry(
          userId: userId,
          result: finalResult,
          source: widget.args.source,
        );
    if (mounted) context.go('/chat');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Confirm meal')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _mealNameController,
            decoration: const InputDecoration(labelText: 'Meal name'),
          ),
          const SizedBox(height: 16),
          NutritionCard(result: _result.copyWith(mealName: _mealNameController.text)),
          const SizedBox(height: 16),
          Text('Items', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (var i = 0; i < _result.items.length; i++) _EditableItemRow(
            item: _result.items[i],
            onChanged: (updated) => _updateItem(i, updated),
            onRemove: () => _removeItem(i),
          ),
          const SizedBox(height: 24),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.inputRadius)),
            ),
            onPressed: _saving || _result.items.isEmpty ? null : _save,
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save to log'),
          ),
        ],
      ),
    );
  }
}

class _EditableItemRow extends StatefulWidget {
  const _EditableItemRow({required this.item, required this.onChanged, required this.onRemove});

  final NutritionItem item;
  final ValueChanged<NutritionItem> onChanged;
  final VoidCallback onRemove;

  @override
  State<_EditableItemRow> createState() => _EditableItemRowState();
}

class _EditableItemRowState extends State<_EditableItemRow> {
  late final TextEditingController _nameController = TextEditingController(text: widget.item.name);
  late final TextEditingController _gramsController = TextEditingController(text: widget.item.estimatedGrams.round().toString());
  late final TextEditingController _caloriesController = TextEditingController(text: widget.item.calories.round().toString());

  @override
  void dispose() {
    _nameController.dispose();
    _gramsController.dispose();
    _caloriesController.dispose();
    super.dispose();
  }

  void _emit() {
    widget.onChanged(widget.item.copyWith(
      name: _nameController.text,
      estimatedGrams: double.tryParse(_gramsController.text) ?? widget.item.estimatedGrams,
      calories: double.tryParse(_caloriesController.text) ?? widget.item.calories,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 3,
            child: TextField(controller: _nameController, onChanged: (_) => _emit(), decoration: const InputDecoration(isDense: true, labelText: 'Item')),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _gramsController,
              onChanged: (_) => _emit(),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(isDense: true, labelText: 'g'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _caloriesController,
              onChanged: (_) => _emit(),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(isDense: true, labelText: 'kcal'),
            ),
          ),
          IconButton(icon: const Icon(Icons.close, size: 18), onPressed: widget.onRemove),
        ],
      ),
    );
  }
}
