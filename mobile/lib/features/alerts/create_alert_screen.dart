import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/models/alert_models.dart';
import '../../shared/repositories/alert_repository.dart';
import '../auth/auth_state.dart';

/// Natural language → structured rule, via `POST /alerts/compile`
/// (API_SPEC.md). The compiled rule is only ever persisted after the user
/// explicitly confirms `confirmation_text` — ARCHITECTURE.md §10: "The
/// backend shows the compiled rule back to the user for confirmation
/// before the client persists it locally."
class CreateAlertScreen extends ConsumerStatefulWidget {
  const CreateAlertScreen({super.key});

  @override
  ConsumerState<CreateAlertScreen> createState() => _CreateAlertScreenState();
}

class _CreateAlertScreenState extends ConsumerState<CreateAlertScreen> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;
  AlertCompileResponse? _compiled;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _compile() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
      _compiled = null;
    });
    try {
      final result = await ref.read(alertRepositoryProvider).compileRule(text);
      setState(() => _compiled = result);
    } catch (e) {
      setState(() => _error = 'Could not understand that. Try rephrasing, e.g. "tell me if my resting heart rate goes above 90".');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _confirm() async {
    final userId = ref.read(currentUserIdProvider);
    final compiled = _compiled;
    if (userId == null || compiled == null) return;
    await ref.read(alertRepositoryProvider).saveConfirmedRule(
          userId: userId,
          compiled: compiled,
          createdFromText: _controller.text.trim(),
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New alert')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'e.g. "Notify me if my resting heart rate goes above 90"',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.inputRadius)),
              ),
              onPressed: _loading ? null : _compile,
              child: _loading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Preview alert'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            if (_compiled != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondary,
                  borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                ),
                child: Text(_compiled!.confirmationText, style: Theme.of(context).textTheme.bodyLarge),
              ),
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.inputRadius)),
                ),
                onPressed: _confirm,
                child: const Text('Confirm & save'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
