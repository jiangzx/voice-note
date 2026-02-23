import 'dart:math' show log, pow;
import 'dart:ui' show FontFeature;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/design_tokens.dart';
import '../../../../app/theme.dart';
import '../../domain/models/trend_point.dart';
import '../providers/statistics_providers.dart';

/// 每日趋势柱状图，支持 支出|收入|结余。企业级风格：紧凑轴线、等宽数字、柔和网格。
class BarChartWidget extends ConsumerWidget {
  const BarChartWidget({super.key});

  static const _chartHeight = 184.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendAsync = ref.watch(trendDataProvider);
    final periodType = ref.watch(selectedPeriodTypeProvider);
    final series = ref.watch(trendSeriesProvider);
    final txColors = transactionColorsOrFallback(Theme.of(context));

    return SizedBox(
      height: _chartHeight,
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

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final axisStyle = textTheme.labelSmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w500,
    );
    final barValueColor = colorScheme.primary;
    final barZeroColor = colorScheme.surfaceContainerHighest;

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
                width: 6,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
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
                width: 6,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
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
                width: 6,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
              ),
            ],
            showingTooltipIndicators: [],
          );
        },
      );
    }
    final maxYPadded = maxY * 1.2;
    if (maxYPadded == 0) return const SizedBox();

    // Y 轴刻度间隔：约 4 档、取「好看」步长，避免 300/310 等贴在一起重叠
    final yInterval = _niceYInterval(maxYPadded);

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
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      label,
                      style: axisStyle,
                    ),
                  );
                }
                return const SizedBox();
              },
              reservedSize: 24,
              interval: points.length > 7 ? (points.length / 7).ceilToDouble() : 1,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 48,
              interval: yInterval,
              maxIncluded: false,
              getTitlesWidget: (value, meta) {
                final label = value >= 1000
                    ? '${(value / 1000).round()}k'
                    : value.toStringAsFixed(0);
                final baseStyle = axisStyle ?? textTheme.bodySmall;
                return SizedBox(
                  width: 40,
                  child: FittedBox(
                    alignment: Alignment.centerRight,
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      style: baseStyle?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
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
            color: colorScheme.outline.withValues(alpha: 0.12),
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

/// Y 轴约 4 档刻度的「好看」步长，避免刻度过密重叠。
double _niceYInterval(double maxY) {
  if (maxY <= 0) return 1.0;
  final x = maxY / 4;
  if (x <= 1) return 1.0;
  final exp = (log(x) / log(10)).floor();
  final magnitude = pow(10, exp).toDouble();
  final norm = x / magnitude;
  final nice =
      norm <= 1 ? 1.0 : norm <= 2 ? 2.0 : norm <= 5 ? 5.0 : 10.0;
  return nice * magnitude;
}
