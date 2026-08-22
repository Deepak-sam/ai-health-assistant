import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../features/health/models/health_models.dart' as domain;

enum ChartRangeOption { d7, d30, d90, custom }

/// A metric trend chart with a 7d/30d/90d/custom range toggle, backed by
/// [fetchMetrics] — typically `HealthRepository.getMetrics` for a single
/// metric type. Only fetches from local Drift data; never calls the
/// backend for chart data (ARCHITECTURE.md §9 local-first).
class ChartCard extends StatefulWidget {
  const ChartCard({
    super.key,
    required this.title,
    required this.unit,
    required this.fetchMetrics,
    this.initialRange = ChartRangeOption.d30,
  });

  final String title;
  final String unit;
  final Future<List<domain.HealthMetric>> Function(domain.DateRange range) fetchMetrics;
  final ChartRangeOption initialRange;

  @override
  State<ChartCard> createState() => _ChartCardState();
}

class _ChartCardState extends State<ChartCard> {
  late ChartRangeOption _range = widget.initialRange;
  DateTimeRange? _customRange;
  late Future<List<domain.HealthMetric>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = widget.fetchMetrics(_resolveRange());
  }

  domain.DateRange _resolveRange() {
    final now = DateTime.now();
    switch (_range) {
      case ChartRangeOption.d7:
        return domain.DateRange.lastDays(7, now: now);
      case ChartRangeOption.d30:
        return domain.DateRange.lastDays(30, now: now);
      case ChartRangeOption.d90:
        return domain.DateRange.lastDays(90, now: now);
      case ChartRangeOption.custom:
        return domain.DateRange(
          start: _customRange?.start ?? now.subtract(const Duration(days: 30)),
          end: _customRange?.end ?? now,
        );
    }
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
      initialDateRange: _customRange,
    );
    if (picked != null) {
      setState(() {
        _range = ChartRangeOption.custom;
        _customRange = picked;
        _reload();
      });
    }
  }

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
        children: [
          Text(widget.title, style: AppTextStyles.title.copyWith(color: theme.colorScheme.onSurface)),
          const SizedBox(height: 12),
          _RangeToggle(
            selected: _range,
            onSelected: (option) {
              if (option == ChartRangeOption.custom) {
                _pickCustomRange();
                return;
              }
              setState(() {
                _range = option;
                _reload();
              });
            },
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: FutureBuilder<List<domain.HealthMetric>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final metrics = snapshot.data ?? const [];
                if (metrics.isEmpty) {
                  return Center(child: Text('No data for this range', style: theme.textTheme.bodySmall));
                }
                return LineChart(_buildChartData(metrics, theme));
              },
            ),
          ),
        ],
      ),
    );
  }

  LineChartData _buildChartData(List<domain.HealthMetric> metrics, ThemeData theme) {
    final sorted = [...metrics]..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final start = sorted.first.timestamp;
    final spots = sorted
        .map((m) => FlSpot(m.timestamp.difference(start).inHours / 24.0, m.value))
        .toList(growable: false);

    return LineChartData(
      gridData: const FlGridData(show: true, drawVerticalLine: false),
      titlesData: FlTitlesData(
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 26,
            getTitlesWidget: (value, meta) {
              final date = start.add(Duration(hours: (value * 24).round()));
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('${date.month}/${date.day}', style: theme.textTheme.bodySmall),
              );
            },
          ),
        ),
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 36)),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: theme.colorScheme.primary,
          barWidth: 2.5,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: true, color: theme.colorScheme.primary.withOpacity(0.08)),
        ),
      ],
    );
  }
}

class _RangeToggle extends StatelessWidget {
  const _RangeToggle({required this.selected, required this.onSelected});

  final ChartRangeOption selected;
  final ValueChanged<ChartRangeOption> onSelected;

  @override
  Widget build(BuildContext context) {
    Widget segment(String label, ChartRangeOption option) {
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: selected == option,
          onSelected: (_) => onSelected(option),
        ),
      );
    }

    return Row(
      children: [
        segment('7d', ChartRangeOption.d7),
        segment('30d', ChartRangeOption.d30),
        segment('90d', ChartRangeOption.d90),
        segment('Custom', ChartRangeOption.custom),
      ],
    );
  }
}
