import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/repositories/nutrition_repository.dart';
import 'nutrition_confirm_screen.dart';

/// Free-text meal logging — `POST /nutrition/text` (API_SPEC.md).
class NutritionTextEntryScreen extends ConsumerStatefulWidget {
  const NutritionTextEntryScreen({super.key});

  @override
  ConsumerState<NutritionTextEntryScreen> createState() => _NutritionTextEntryScreenState();
}

class _NutritionTextEntryScreenState extends ConsumerState<NutritionTextEntryScreen> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref.read(nutritionRepositoryProvider).analyzeText(text);
      if (!mounted) return;
      context.push('/nutrition/confirm', extra: NutritionConfirmArgs(result: result, source: 'text'));
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not parse that. Try describing it differently.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Describe your meal')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              maxLines: 4,
              decoration: const InputDecoration(hintText: 'e.g. "Two eggs, toast, and a coffee"'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 20),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.inputRadius)),
              ),
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Estimate nutrition'),
            ),
          ],
        ),
      ),
    );
  }
}
