import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/design_tokens.dart';
import '../../../../app/theme.dart';
import '../../../../core/utils/color_utils.dart';
import '../../domain/models/category_summary.dart';
import '../providers/statistics_providers.dart';

/// Pie chart showing category distribution with expense/income toggle.
class PieChartWidget extends ConsumerWidget {
  const PieChartWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categorySummaryProvider);
    final txColors = transactionColorsOrFallback(Theme.of(context));

    return categoriesAsync.when(
      data: (categories) => _PieChartContent(
        categories: categories,
        txColors: txColors,
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('加载失败: $e', style: TextStyle(color: txColors.expense)),
      ),
    );
  }
}

class _PieChartContent extends StatefulWidget {
  const _PieChartContent({
    required this.categories,
    required this.txColors,
  });

  final List<CategorySummary> categories;
  final TransactionColors txColors;

  @override
  State<_PieChartContent> createState() => _PieChartContentState();
}

class _PieChartContentState extends State<_PieChartContent> {
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    final total =
        widget.categories.fold<double>(0, (s, c) => s + c.totalAmount);
    if (widget.categories.isEmpty || total == 0) {
      return Center(
        child: Text(
          '暂无数据',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );
    }

    final sections = List<PieChartSectionData>.generate(
      widget.categories.length,
      (i) {
        final c = widget.categories[i];
        final isTouched = i == _touchedIndex;
        final color = _parseColor(c.color);
        return PieChartSectionData(
          value: c.totalAmount,
          title: '',
          color: isTouched ? color.withValues(alpha: 0.8) : color,
          radius: isTouched ? 62 : 54,
          titleStyle: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          showTitle: c.totalAmount > 0,
        );
      },
    );

    return PieChart(
      PieChartData(
        sections: sections,
        sectionsSpace: 2,
        centerSpaceRadius: 48,
        pieTouchData: PieTouchData(
          touchCallback: (FlTouchEvent event, pieTouchResponse) {
            setState(() {
              if (!event.isInterestedForInteractions ||
                  pieTouchResponse == null ||
                  pieTouchResponse.touchedSection == null) {
                _touchedIndex = null;
                return;
              }
              _touchedIndex =
                  pieTouchResponse.touchedSection!.touchedSectionIndex;
            });
          },
        ),
      ),
      duration: AppDuration.normal,
    );
  }

  Color _parseColor(String hex) {
    try {
      return colorFromArgbHex(hex);
    } catch (_) {
      return widget.txColors.expense;
    }
  }
}
