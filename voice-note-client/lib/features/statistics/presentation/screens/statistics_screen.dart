import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/design_tokens.dart';
import '../../../../app/theme.dart';
import '../../../../shared/widgets/error_state_widget.dart';
import '../../../../shared/widgets/swipe_back_zone.dart';
import '../../../../shared/widgets/shimmer_placeholder.dart';
import '../../../account/presentation/providers/account_providers.dart';
import '../providers/statistics_providers.dart';
import '../widgets/bar_chart_widget.dart';
import '../widgets/bill_summary_table.dart';
import '../widgets/category_ranking.dart';
import '../widgets/period_selector.dart';
import '../widgets/pie_chart_widget.dart';
import '../widgets/single_transaction_ranking.dart';

/// 统计页：时间范围 → 汇总 → 每日趋势(柱) → 分类构成(饼) → 单笔排行(Top10) → 账单汇总表。
class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  static const _sectionStyle = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
    letterSpacing: 0.8,
  );
  static const _cardRadius = 10.0;
  static const _cardBorder = Color(0xFFEBEDF0);
  static const _cardPaddingH = 12.0;
  static const _cardPaddingV = 10.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uri = GoRouterState.of(context).uri;
    final yearStr = uri.queryParameters['year'];
    final monthStr = uri.queryParameters['month'];
    if (yearStr != null && monthStr != null) {
      final year = int.tryParse(yearStr);
      final month = int.tryParse(monthStr);
      if (year != null &&
          month != null &&
          month >= 1 &&
          month <= 12) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          ref.read(selectedDateProvider.notifier).state = DateTime(year, month);
          ref.read(selectedPeriodTypeProvider.notifier).state = PeriodType.month;
          // Do not call context.go() here: it would replace the stack and remove the back button.
        });
      }
    }

    final theme = Theme.of(context);
    final txColors = theme.extension<TransactionColors>()!;
    final accountsAsync = ref.watch(accountListProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundSecondary,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
          tooltip: '返回',
        ),
        title: const Text(
          '统计',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.backgroundPrimary,
        foregroundColor: AppColors.textPrimary,
        actions: [
          PopupMenuButton<String?>(
            icon: const Icon(
              Icons.account_balance_wallet_outlined,
              size: 22,
              color: AppColors.textSecondary,
            ),
            tooltip: '选择账户',
            onSelected: (id) {
              ref.read(selectedAccountIdProvider.notifier).state = id;
            },
            itemBuilder: (context) {
              return [
                const PopupMenuItem(value: null, child: Text('全部账户')),
                ...accountsAsync.when(
                  data: (accounts) => accounts
                      .map(
                        (a) => PopupMenuItem(value: a.id, child: Text(a.name)),
                      )
                      .toList(),
                  loading: () => [],
                  error: (e, st) => [],
                ),
              ];
            },
          ),
        ],
      ),
      body: SwipeBackZone(
        onBack: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/home');
          }
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          children: [
          const PeriodSelector(),
          const SizedBox(height: 12),
          _sectionTitle('汇总'),
          _SummaryCard(txColors: txColors),
          const SizedBox(height: 12),
          _sectionRow('每日支出趋势', _trendToggle(ref)),
          const SizedBox(height: 4),
          const _TrendDateDetailRow(),
          const SizedBox(height: 8),
          _chartCard(const BarChartWidget()),
          const SizedBox(height: 12),
          _sectionRow('支出分类构成', _categoryTypeToggle(ref)),
          const SizedBox(height: 8),
          _chartCard(const _CategoryCompositionSection()),
          const SizedBox(height: 12),
          _sectionRow('单笔支出排行榜', _rankingTypeToggle(ref)),
          _chartCard(const SingleTransactionRanking()),
          const SizedBox(height: 12),
          _sectionTitle('账单汇总'),
          const BillSummaryTable(),
        ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(title, style: _sectionStyle),
    );
  }

  /// 区块一行：左侧标题，右侧分段控制（参考图）。
  Widget _sectionRow(String title, Widget segmentedControl) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(title, style: _sectionStyle),
          const Spacer(),
          segmentedControl,
        ],
      ),
    );
  }

  Widget _trendToggle(WidgetRef ref) {
    final series = ref.watch(trendSeriesProvider);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _segmentedChip(
          ref,
          label: '支出',
          value: 'expense',
          current: series,
          onTap: () => ref.read(trendSeriesProvider.notifier).state = 'expense',
        ),
        const SizedBox(width: AppSpacing.sm),
        _segmentedChip(
          ref,
          label: '收入',
          value: 'income',
          current: series,
          onTap: () => ref.read(trendSeriesProvider.notifier).state = 'income',
        ),
        const SizedBox(width: AppSpacing.sm),
        _segmentedChip(
          ref,
          label: '结余',
          value: 'balance',
          current: series,
          onTap: () => ref.read(trendSeriesProvider.notifier).state = 'balance',
        ),
      ],
    );
  }

  Widget _segmentedChip(
    WidgetRef ref, {
    required String label,
    required String value,
    required String current,
    required VoidCallback onTap,
  }) {
    final isSelected = value == current;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.brandPrimary
              : AppColors.backgroundPrimary,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? AppColors.brandPrimary : _cardBorder,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _categoryTypeToggle(WidgetRef ref) {
    final type = ref.watch(categorySummaryTypeProvider);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _segmentedChip(
          ref,
          label: '支出',
          value: 'expense',
          current: type,
          onTap: () =>
              ref.read(categorySummaryTypeProvider.notifier).state = 'expense',
        ),
        const SizedBox(width: AppSpacing.sm),
        _segmentedChip(
          ref,
          label: '收入',
          value: 'income',
          current: type,
          onTap: () =>
              ref.read(categorySummaryTypeProvider.notifier).state = 'income',
        ),
      ],
    );
  }

  Widget _rankingTypeToggle(WidgetRef ref) {
    final type = ref.watch(singleRankingTypeProvider);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _segmentedChip(
          ref,
          label: '支出',
          value: 'expense',
          current: type,
          onTap: () =>
              ref.read(singleRankingTypeProvider.notifier).state = 'expense',
        ),
        const SizedBox(width: AppSpacing.sm),
        _segmentedChip(
          ref,
          label: '收入',
          value: 'income',
          current: type,
          onTap: () =>
              ref.read(singleRankingTypeProvider.notifier).state = 'income',
        ),
      ],
    );
  }

  Widget _chartCard(Widget child) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundPrimary,
        borderRadius: BorderRadius.circular(_cardRadius),
        border: Border.all(color: _cardBorder, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            offset: Offset(0, 1),
            blurRadius: 4,
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: _cardPaddingH,
        vertical: _cardPaddingV,
      ),
      child: child,
    );
  }
}

/// 每日趋势下可点行：日期 + 类型 + 金额，点击进入该日账单。
class _TrendDateDetailRow extends ConsumerWidget {
  const _TrendDateDetailRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(effectiveDateRangeProvider);
    final trendAsync = ref.watch(trendDataProvider);
    final series = ref.watch(trendSeriesProvider);
    final theme = Theme.of(context);
    final date = range.start;
    final dateStr = '${date.month}月${date.day}日';
    final label = series == 'expense'
        ? '支出'
        : series == 'income'
        ? '收入'
        : '结余';

    return trendAsync.when(
      data: (points) {
        double amount = 0;
        if (points.isNotEmpty) {
          final p = points.first;
          if (series == 'expense') {
            amount = p.expense;
          } else if (series == 'income') {
            amount = p.income;
          } else {
            amount = p.income - p.expense;
          }
        }
        final from = date.toIso8601String().split('T').first;
        final to = from;
        return InkWell(
          onTap: () => context.go('/transactions?dateFrom=$from&dateTo=$to'),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Text(
                  '$dateStr $label ¥${amount.toStringAsFixed(2)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        );
      },
      loading: () => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Text(
          '$dateStr $label —',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ),
      error: (e, st) => const SizedBox.shrink(),
    );
  }
}

class _SummaryCard extends ConsumerWidget {
  const _SummaryCard({required this.txColors});

  final TransactionColors txColors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(periodSummaryProvider);

    return summaryAsync.when(
      data: (summary) => Container(
        decoration: BoxDecoration(
          color: AppColors.backgroundPrimary,
          borderRadius: BorderRadius.circular(StatisticsScreen._cardRadius),
          border: Border.all(color: StatisticsScreen._cardBorder, width: 1),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D000000),
              offset: Offset(0, 1),
              blurRadius: 4,
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        child: Row(
          children: [
            Expanded(
              child: _SummaryItem(
                label: '支出',
                amount: summary.totalExpense,
                color: txColors.expense,
              ),
            ),
            Expanded(
              child: _SummaryItem(
                label: '收入',
                amount: summary.totalIncome,
                color: txColors.income,
              ),
            ),
            Expanded(
              child: _SummaryItem(
                label: '结余',
                amount: summary.balance,
                color: summary.balance >= 0
                    ? txColors.income
                    : txColors.expense,
              ),
            ),
          ],
        ),
      ),
      loading: () => ShimmerPlaceholder.card(height: 64),
      error: (e, st) => ErrorStateWidget(
        message: '汇总加载失败: $e',
        onRetry: () => ref.invalidate(periodSummaryProvider),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.label,
    required this.amount,
    required this.color,
  });

  final String label;
  final double amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textPlaceholder,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '¥${amount.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}

class _PieChartSection extends ConsumerWidget {
  const _PieChartSection();

  /// 根据周期类型与支出/收入得到中心文案（如「本月支出」）。
  static String _centerLabel(PeriodType periodType, String type) {
    final suffix = type == 'expense' ? '支出' : '收入';
    switch (periodType) {
      case PeriodType.week:
        return '本周$suffix';
      case PeriodType.month:
        return '本月$suffix';
      case PeriodType.year:
        return '本年$suffix';
      case PeriodType.custom:
        return '本周期$suffix';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categorySummaryProvider);
    final type = ref.watch(categorySummaryTypeProvider);
    final periodType = ref.watch(selectedPeriodTypeProvider);
    final labelText = _centerLabel(periodType, type);
    final theme = Theme.of(context);

    return categoriesAsync.when(
      data: (categories) {
        final total = categories.fold<double>(0, (s, c) => s + c.totalAmount);
        if (categories.isEmpty || total == 0) {
          return const SizedBox.shrink();
        }
        return SizedBox(
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              const PieChartWidget(),
              Center(
                child: SizedBox(
                  width: 88,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          labelText,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textPlaceholder,
                            fontSize: 10,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '¥${total.toStringAsFixed(2)}',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, st) => const SizedBox.shrink(),
    );
  }
}

/// 支出分类构成卡片：饼图 + 分类构成列表（原单笔支出排行下面的内容）。
class _CategoryCompositionSection extends StatelessWidget {
  const _CategoryCompositionSection();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PieChartSection(),
        SizedBox(height: 12),
        Divider(height: 1, indent: 12, endIndent: 12, color: Color(0xFFEBEDF0)),
        SizedBox(height: 12),
        CategoryRanking(),
      ],
    );
  }
}
