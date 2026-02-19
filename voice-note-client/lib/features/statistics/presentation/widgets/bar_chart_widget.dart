import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/design_tokens.dart';
import '../../../../app/theme.dart';
import '../../domain/models/trend_point.dart';
import '../providers/statistics_providers.dart';

/// Bar chart showing income vs expense side by side.
class BarChartWidget extends ConsumerWidget {
  const BarChartWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendAsync = ref.watch(trendDataProvider);
    final periodType = ref.watch(selectedPeriodTypeProvider);
    final txColors = Theme.of(context).extension<TransactionColors>()!;

    return SizedBox(
      height: 220,
      child: trendAsync.when(
        data: (points) => _BarChartContent(
          points: points,
          periodType: periodType,
          txColors: txColors,
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            '加载失败: $e',
            style: TextStyle(color: txColors.expense),
          ),
        ),
      ),
    );
  }
}

class _BarChartContent extends StatelessWidget {
  const _BarChartContent({
    required this.points,
    required this.periodType,
    required this.txColors,
  });

  final List<TrendPoint> points;
  final PeriodType periodType;
  final TransactionColors txColors;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return Center(
        child: Text(
          '暂无数据',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );
    }

    final maxY = points.fold<double>(
      0,
      (m, p) {
        final maxVal = p.income > p.expense ? p.income : p.expense;
        return maxVal > m ? maxVal : m;
      },
    );
    final maxYPadded = maxY * 1.2;
    if (maxYPadded == 0) return const SizedBox();

    final barGroups = List.generate(
      points.length,
      (i) {
        final p = points[i];
        return BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: p.income,
              color: txColors.income,
              width: 8,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
            ),
            BarChartRodData(
              toY: p.expense,
              color: txColors.expense,
              width: 8,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
            ),
          ],
          showingTooltipIndicators: [],
        );
      },
    );

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxYPadded,
        barTouchData: const BarTouchData(enabled: true),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < points.length) {
                  final label = _formatLabel(points[value.toInt()].date);
                  return Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  );
                }
                return const SizedBox();
              },
              reservedSize: 28,
              interval: points.length > 7 ? (points.length / 7).ceilToDouble() : 1,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  value >= 1000 ? '${(value / 1000).toStringAsFixed(1)}k' : value.toStringAsFixed(0),
                  style: Theme.of(context).textTheme.bodySmall,
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: barGroups,
      ),
      duration: AppDuration.normal,
    );
  }

  String _formatLabel(String dateStr) {
    if (periodType == PeriodType.year) {
      return dateStr.length >= 7 ? dateStr.substring(5) : dateStr;
    }
    if (dateStr.length >= 10) {
      return dateStr.substring(8);
    }
    return dateStr;
  }
}
