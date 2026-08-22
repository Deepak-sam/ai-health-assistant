import 'package:flutter/material.dart';

import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';

/// Renders a `ChatCard` of type `health_metric` (see shared/models/chat_models.dart)
/// inline under an assistant message — a calm rounded metric summary, not a
/// clinical readout.
class HealthCard extends StatelessWidget {
  const HealthCard({super.key, required this.title, this.subtitle, required this.metrics});

  final String title;
  final String? subtitle;
  final Map<String, dynamic> metrics;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: AppTextStyles.title.copyWith(color: Theme.of(context).colorScheme.onSurface)),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 20,
            runSpacing: 12,
            children: metrics.entries.map((e) => _MetricTile(label: e.key, value: e.value)).toList(),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});

  final String label;
  final dynamic value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$value', style: AppTextStyles.metricValue.copyWith(color: Theme.of(context).colorScheme.primary)),
        const SizedBox(height: 2),
        Text(_humanizeLabel(label), style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  String _humanizeLabel(String key) => key.replaceAll('_', ' ');
}
