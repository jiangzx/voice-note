import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/design_tokens.dart';
import '../../../../app/theme.dart';
import '../../../../shared/widgets/error_state_widget.dart';
import '../../../../shared/widgets/shimmer_placeholder.dart';
import '../../../account/presentation/providers/account_providers.dart';
import '../providers/statistics_providers.dart';
import '../widgets/bar_chart_widget.dart';
import '../widgets/category_ranking.dart';
import '../widgets/period_selector.dart';
import '../widgets/pie_chart_widget.dart';
import '../widgets/trend_chart_widget.dart';

/// Statistics screen with period selector, summary, charts, and category ranking.
class StatisticsScreen extends ConsumerStatefulWidget {
  const StatisticsScreen({super.key});

  @override
  ConsumerState<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends ConsumerState<StatisticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final txColors = theme.extension<TransactionColors>()!;
    final accountsAsync = ref.watch(accountListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('统计'),
        actions: [
          PopupMenuButton<String?>(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            tooltip: '选择账户',
            onSelected: (id) {
              ref.read(selectedAccountIdProvider.notifier).update((_) => id);
            },
            itemBuilder: (context) {
              return [
                const PopupMenuItem(
                  value: null,
                  child: Text('全部账户'),
                ),
                ...accountsAsync.when(
                  data: (accounts) => accounts
                      .map(
                        (a) => PopupMenuItem(
                          value: a.id,
                          child: Text(a.name),
                        ),
                      )
                      .toList(),
                  loading: () => [],
                  error: (_, st) => [],
                ),
              ];
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '饼图'),
            Tab(text: '柱状图'),
            Tab(text: '折线图'),
          ],
        ),
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: PeriodSelector(),
          ),
          _PeriodSummaryCard(txColors: txColors),
          _ComparisonSection(txColors: txColors),
          SizedBox(
            height: 320,
            child: TabBarView(
              controller: _tabController,
              children: const [
                Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: PieChartWidget(),
                ),
                Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: BarChartWidget(),
                ),
                Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: TrendChartWidget(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text(
              '分类排行',
              style: theme.textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const CategoryRanking(),
        ],
      ),
    );
  }
}

class _PeriodSummaryCard extends ConsumerWidget {
  const _PeriodSummaryCard({required this.txColors});

  final TransactionColors txColors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(periodSummaryProvider);

    return summaryAsync.when(
      data: (summary) => Card(
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Row(
            children: [
              Expanded(
                child: _SummaryItem(
                  label: '收入',
                  amount: summary.totalIncome,
                  color: txColors.income,
                ),
              ),
              Expanded(
                child: _SummaryItem(
                  label: '支出',
                  amount: summary.totalExpense,
                  color: txColors.expense,
                ),
              ),
              Expanded(
                child: _SummaryItem(
                  label: '结余',
                  amount: summary.balance,
                  color: summary.balance >= 0 ? txColors.income : txColors.expense,
                ),
              ),
            ],
          ),
        ),
      ),
      loading: () => ShimmerPlaceholder.card(height: 80),
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
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '¥${amount.toStringAsFixed(2)}',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

class _ComparisonSection extends ConsumerWidget {
  const _ComparisonSection({required this.txColors});

  final TransactionColors txColors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentAsync = ref.watch(periodSummaryProvider);
    final previousAsync = ref.watch(previousPeriodSummaryProvider);

    return currentAsync.when(
      data: (current) => previousAsync.when(
        data: (previous) {
          final incomeChange = _percentChange(
            previous.totalIncome,
            current.totalIncome,
          );
          final expenseChange = _percentChange(
            previous.totalExpense,
            current.totalExpense,
          );
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Expanded(
                  child: _ChangeIndicator(
                    label: '收入环比',
                    change: incomeChange,
                    txColors: txColors,
                    positiveIsGood: true,
                  ),
                ),
                Expanded(
                  child: _ChangeIndicator(
                    label: '支出环比',
                    change: expenseChange,
                    txColors: txColors,
                    positiveIsGood: false,
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const SizedBox.shrink(),
        error: (_, st) => const SizedBox.shrink(),
      ),
      loading: () => const SizedBox.shrink(),
        error: (_, st) => const SizedBox.shrink(),
    );
  }

  double? _percentChange(double prev, double curr) {
    if (prev == 0) return curr > 0 ? 100 : null;
    return ((curr - prev) / prev) * 100;
  }
}

class _ChangeIndicator extends StatelessWidget {
  const _ChangeIndicator({
    required this.label,
    required this.change,
    required this.txColors,
    required this.positiveIsGood,
  });

  final String label;
  final double? change;
  final TransactionColors txColors;
  final bool positiveIsGood;

  @override
  Widget build(BuildContext context) {
    if (change == null) return const SizedBox.shrink();

    final isPositive = change! > 0;
    final isGood = positiveIsGood ? isPositive : !isPositive;
    final color = isGood ? txColors.income : txColors.expense;
    final icon = isPositive ? Icons.trending_up : Icons.trending_down;
    final sign = change! >= 0 ? '+' : '';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: AppSpacing.xs),
        Text(
          '$label $sign${change!.toStringAsFixed(1)}%',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
        ),
      ],
    );
  }
}
