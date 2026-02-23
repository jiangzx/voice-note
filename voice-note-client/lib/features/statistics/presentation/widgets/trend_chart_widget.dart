import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/design_tokens.dart';
import '../../../../app/theme.dart';
import '../../domain/models/trend_point.dart';
import '../providers/statistics_providers.dart';

/// Line chart showing income and expense trend with dot markers.
class TrendChartWidget extends ConsumerWidget {
  const TrendChartWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendAsync = ref.watch(trendDataProvider);
    final periodType = ref.watch(selectedPeriodTypeProvider);
    final txColors = transactionColorsOrFallback(Theme.of(context));

    return SizedBox(
      height: 220,
      child: trendAsync.when(
        data: (points) => _TrendChartContent(
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

class _TrendChartContent extends StatelessWidget {
  const _TrendChartContent({
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

    final incomeSpots = points
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.income))
        .toList();
    final expenseSpots = points
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.expense))
        .toList();

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
            strokeWidth: 1,
          ),
        ),
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
                  value >= 1000
                      ? '${(value / 1000).toStringAsFixed(1)}k'
                      : value.toStringAsFixed(0),
                  style: Theme.of(context).textTheme.bodySmall,
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (points.length - 1).toDouble(),
        minY: 0,
        maxY: maxYPadded,
        lineBarsData: [
          LineChartBarData(
            spots: incomeSpots,
            isCurved: true,
            color: txColors.income,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(show: false),
          ),
          LineChartBarData(
            spots: expenseSpots,
            isCurved: true,
            color: txColors.expense,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(show: false),
          ),
        ],
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
