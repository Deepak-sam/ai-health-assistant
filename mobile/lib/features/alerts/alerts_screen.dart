import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/app_database.dart' as db;
import '../../core/theme/app_theme.dart';
import '../../shared/repositories/alert_repository.dart';
import '../auth/auth_state.dart';

/// View/manage alert rules. Creation flow lives in [CreateAlertScreen] —
/// this screen only lists and toggles/deletes existing rules
/// (ARCHITECTURE.md §10: compile happens once via the LLM; this UI never
/// re-invokes it after creation).
class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final rulesAsync = ref.watch(_rulesStreamProvider(userId));

    return Scaffold(
      appBar: AppBar(title: const Text('Alerts')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/settings/alerts/create'),
        icon: const Icon(Icons.add),
        label: const Text('New alert'),
      ),
      body: rulesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(child: Text('Could not load alerts.')),
        data: (rules) {
          if (rules.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'No alerts yet. Try "New alert" and describe what you want to be notified about.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: rules.length,
            itemBuilder: (context, index) => _RuleTile(rule: rules[index], userId: userId),
          );
        },
      ),
    );
  }
}

class _RuleTile extends ConsumerWidget {
  const _RuleTile({required this.rule, required this.userId});

  final db.AlertRule rule;
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(rule.createdFromText, style: theme.textTheme.bodyLarge),
                const SizedBox(height: 4),
                Text(rule.metricType.replaceAll('_', ' '), style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          Switch(
            value: rule.enabled,
            onChanged: (v) => ref.read(alertRepositoryProvider).setEnabled(userId: userId, ruleId: rule.id, enabled: v),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: () => ref.read(alertRepositoryProvider).deleteRule(userId: userId, ruleId: rule.id),
          ),
        ],
      ),
    );
  }
}

final _rulesStreamProvider = StreamProvider.family<List<db.AlertRule>, String>((ref, userId) {
  return ref.watch(alertRepositoryProvider).watchRules(userId);
});
