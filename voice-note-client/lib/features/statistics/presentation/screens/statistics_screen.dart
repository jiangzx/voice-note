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
    final amountStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
      color: color,
      fontWeight: FontWeight.w600,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xs),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '¥${amount.toStringAsFixed(2)}',
            style: amountStyle,
            textAlign: TextAlign.center,
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}

