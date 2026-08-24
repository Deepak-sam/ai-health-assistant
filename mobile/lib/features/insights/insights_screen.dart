import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart' as db;
import '../../core/theme/app_theme.dart';
import '../../shared/repositories/health_repository.dart';
import '../auth/auth_state.dart';
import '../health/models/health_models.dart' as domain;
import 'insight_generator.dart';

/// Insights tab: runs the deterministic [InsightGenerator] against the last
/// 60 days of `daily_health_summary`, caches new findings into
/// `ai_insights` (deduped per ISO week — see InsightGenerator), and lists
/// the active (non-dismissed) ones.
class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  static const _generator = InsightGenerator();
  final _uuid = const Uuid();
  bool _refreshed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_refreshed) {
      _refreshed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _refreshInsights());
    }
  }

  Future<void> _refreshInsights() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    final database = ref.read(db.appDatabaseProvider);
    final summaries = await ref.read(healthRepositoryProvider).getDailySummaries(
          userId: userId,
          range: domain.DateRange.lastDays(60),
        );
    final generated = _generator.generate(summaries);
    for (final insight in generated) {
      await database.aiInsightsDao.insertIfNew(db.AiInsightsCompanion.insert(
        id: _uuid.v4(),
        userId: userId,
        insightText: insight.text,
        category: insight.category,
        dedupKey: insight.dedupKey,
        surfacedAt: DateTime.now(),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final insightsAsync = ref.watch(_activeInsightsProvider(userId));

    return Scaffold(
      appBar: AppBar(title: const Text('Insights')),
      body: RefreshIndicator(
        onRefresh: _refreshInsights,
        child: insightsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => const Center(child: Text('Could not load insights.')),
          data: (insights) {
            if (insights.isEmpty) {
              return ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'Nothing stands out yet. Check back once you have a couple of weeks of data.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: insights.length,
              itemBuilder: (context, index) => _InsightTile(insight: insights[index], userId: userId),
            );
          },
        ),
      ),
    );
  }
}

class _InsightTile extends ConsumerWidget {
  const _InsightTile({required this.insight, required this.userId});

  final db.AiInsight insight;
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
                Text(insight.insightText, style: theme.textTheme.bodyLarge),
                const SizedBox(height: 6),
                Text(
                  '${_categoryLabel(insight.category)} · ${DateFormat.MMMd().format(insight.surfacedAt)}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            tooltip: 'Dismiss',
            onPressed: () => ref.read(db.appDatabaseProvider).aiInsightsDao.dismiss(userId: userId, id: insight.id),
          ),
        ],
      ),
    );
  }

  String _categoryLabel(String category) => category[0].toUpperCase() + category.substring(1);
}

final _activeInsightsProvider = StreamProvider.family<List<db.AiInsight>, String>((ref, userId) {
  return ref.watch(db.appDatabaseProvider).aiInsightsDao.watchActiveInsights(userId);
});
