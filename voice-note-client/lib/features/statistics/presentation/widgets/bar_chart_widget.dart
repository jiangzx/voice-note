import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/design_tokens.dart';
import '../../../../app/theme.dart';
import '../../domain/models/trend_point.dart';
import '../providers/statistics_providers.dart';

/// Bar chart: 每日趋势，支持 支出|收入|结余 切换。
class BarChartWidget extends ConsumerWidget {
  const BarChartWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendAsync = ref.watch(trendDataProvider);
    final periodType = ref.watch(selectedPeriodTypeProvider);
    final series = ref.watch(trendSeriesProvider);
    final txColors = Theme.of(context).extension<TransactionColors>()!;

    return SizedBox(
      height: 200,
      child: trendAsync.when(
        data: (points) => _BarChartContent(
          points: points,
          periodType: periodType,
          series: series,
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
    required this.series,
    required this.txColors,
  });

  final List<TrendPoint> points;
  final PeriodType periodType;
  final String series;
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

    // 零/低值灰色，有值蓝色（参考图）
    const barZeroColor = Color(0xFFE5E7EB);
    const barValueColor = AppColors.brandPrimary;

    double maxY;
    List<BarChartGroupData> barGroups;
    if (series == 'expense') {
      maxY = points.fold<double>(0, (m, p) => p.expense > m ? p.expense : m);
      barGroups = List.generate(
        points.length,
        (i) {
          final v = points[i].expense;
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: v,
                color: v > 0 ? barValueColor : barZeroColor,
                width: 8,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
              ),
            ],
            showingTooltipIndicators: [],
          );
        },
      );
    } else if (series == 'income') {
      maxY = points.fold<double>(0, (m, p) => p.income > m ? p.income : m);
      barGroups = List.generate(
        points.length,
        (i) {
          final v = points[i].income;
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: v,
                color: v > 0 ? barValueColor : barZeroColor,
                width: 8,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
              ),
            ],
            showingTooltipIndicators: [],
          );
        },
      );
    } else {
      maxY = points.fold<double>(
        0,
        (m, p) {
          final b = p.income - p.expense;
          final abs = b < 0 ? -b : b;
          return abs > m ? abs : m;
        },
      );
      barGroups = List.generate(
        points.length,
        (i) {
          final balance = points[i].income - points[i].expense;
          final absBalance = balance >= 0 ? balance : -balance;
          final color = absBalance > 0 ? barValueColor : barZeroColor;
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: absBalance,
                color: color,
                width: 8,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
              ),
            ],
            showingTooltipIndicators: [],
          );
        },
      );
    }
    final maxYPadded = maxY * 1.2;
    if (maxYPadded == 0) return const SizedBox();

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
              reservedSize: 48,
              getTitlesWidget: (value, meta) {
                final label = value >= 1000
                    ? '${(value / 1000).round()}k'
                    : value.toStringAsFixed(0);
                return SizedBox(
                  width: 36,
                  child: FittedBox(
                    alignment: Alignment.centerRight,
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                    ),
                  ),
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
