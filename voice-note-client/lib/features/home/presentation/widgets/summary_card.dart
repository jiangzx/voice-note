import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/design_tokens.dart';
import '../../../../app/theme.dart';
import '../../../budget/presentation/providers/budget_providers.dart';

const double _kCardRadius = 12;

/// Card: monthly expense hero, income/balance, budget block. Uses theme for dark mode.
class SummaryCard extends ConsumerStatefulWidget {
  const SummaryCard({
    super.key,
    required this.monthLabel,
    required this.totalIncome,
    required this.totalExpense,
    this.monthDate,
  });

  final String monthLabel;
  final double totalIncome;
  final double totalExpense;
  /// When set, tapping the expense block navigates to statistics for this month.
  final DateTime? monthDate;

  @override
  ConsumerState<SummaryCard> createState() => _SummaryCardState();
}

class _SummaryCardState extends ConsumerState<SummaryCard> {
  bool _amountsVisible = true;

  double get _balance => widget.totalIncome - widget.totalExpense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final budgetAsync = ref.watch(budgetSummaryProvider);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final cardWidth = screenWidth * 0.92;
    final horizontalMargin = (screenWidth - cardWidth) / 2;

    return Center(
      child: SizedBox(
        width: cardWidth,
        child: Container(
          margin: EdgeInsets.only(
            left: horizontalMargin,
            right: horizontalMargin,
            top: AppSpacing.sm,
            bottom: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(_kCardRadius),
            border: Border.all(color: scheme.outline, width: 1),
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withValues(alpha: 0.05),
                offset: const Offset(0, 1),
                blurRadius: 3,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTopRow(context, scheme),
                const SizedBox(height: 10),
                _buildHeroAmount(context, scheme),
                const SizedBox(height: 14),
                _buildIncomeBalance(context, theme, scheme),
                const SizedBox(height: 12),
                budgetAsync.when(
                  data: (budget) {
                    if (budget.totalBudget <= 0) {
                      return _BudgetUnsetBlock(onTap: () => context.push('/settings/budget'));
                    }
                    return _BudgetSetBlock(
                      totalBudget: budget.totalBudget,
                      totalSpent: budget.totalSpent,
                      remaining: budget.totalRemaining,
                    );
                  },
                  loading: () => _BudgetUnsetBlock(onTap: () => context.push('/settings/budget')),
                  error: (_, _) => _BudgetUnsetBlock(onTap: () => context.push('/settings/budget')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openStatisticsForMonth() {
    if (widget.monthDate == null) return;
    final d = widget.monthDate!;
    context.push('/statistics?year=${d.year}&month=${d.month}');
  }

  Widget _buildTopRow(BuildContext context, ColorScheme scheme) {
    final monthLabelChild = Text(
      '${widget.monthLabel}支出',
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: scheme.onSurfaceVariant,
        letterSpacing: 0.2,
      ),
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.monthDate != null)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _openStatisticsForMonth,
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: monthLabelChild,
                  ),
                ),
              )
            else
              monthLabelChild,
            const SizedBox(width: 4),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _amountsVisible = !_amountsVisible),
                borderRadius: BorderRadius.circular(20),
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: Center(
                    child: Icon(
                      _amountsVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      size: 18,
                      color: _amountsVisible ? scheme.onSurfaceVariant : scheme.primary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
              child: InkWell(
                onTap: () => context.push('/statistics'),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bar_chart_outlined, size: 16, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        '统计',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => context.push('/settings'),
                borderRadius: BorderRadius.circular(20),
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: Center(
                    child: Icon(Icons.settings_outlined, size: 20, color: scheme.onSurfaceVariant),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeroAmount(BuildContext context, ColorScheme scheme) {
    final expense = widget.totalExpense;
    final str = expense.toStringAsFixed(2);
    final dot = str.indexOf('.');
    final intPart = dot > 0 ? str.substring(0, dot) : str;
    final decPart = dot > 0 ? str.substring(dot) : '';

    final amountContent = !_amountsVisible
        ? Text(
            '¥****',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
              height: 1.2,
              letterSpacing: -0.5,
            ),
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '¥$intPart',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                  height: 1.2,
                  letterSpacing: -0.5,
                ),
              ),
              if (decPart.isNotEmpty)
                Text(
                  decPart,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: scheme.onSurface,
                    height: 1.25,
                  ),
                ),
            ],
          );
    if (widget.monthDate == null) return amountContent;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openStatisticsForMonth,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: amountContent,
        ),
      ),
    );
  }

  Widget _buildIncomeBalance(BuildContext context, ThemeData theme, ColorScheme scheme) {
    final txColors = transactionColorsOrFallback(theme);
    final balanceColor = _balance >= 0 ? scheme.tertiary : scheme.error;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _LabelAmount(
            label: '收入',
            amount: widget.totalIncome,
            visible: _amountsVisible,
            color: txColors.income,
            showSign: false,
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: _LabelAmount(
            label: '结余',
            amount: _balance,
            visible: _amountsVisible,
            color: balanceColor,
            showSign: true,
          ),
        ),
      ],
    );
  }
}

class _LabelAmount extends StatelessWidget {
  const _LabelAmount({
    required this.label,
    required this.amount,
    required this.visible,
    required this.color,
    required this.showSign,
  });

  final String label;
  final double amount;
  final bool visible;
  final Color color;
  final bool showSign;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sign = showSign && amount != 0 ? (amount >= 0 ? '+' : '-') : '';
    final absAmount = amount.abs();
    final display = visible ? '$sign¥${absAmount.toStringAsFixed(2)}' : '¥****';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: scheme.onSurfaceVariant,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            display,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: color,
            ),
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}

class _BudgetUnsetBlock extends StatelessWidget {
  const _BudgetUnsetBlock({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(_kCardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_kCardRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '月预算',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '暂未设置',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '设置',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(Icons.arrow_forward_ios, size: 10, color: scheme.primary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BudgetSetBlock extends StatelessWidget {
  const _BudgetSetBlock({
    required this.totalBudget,
    required this.totalSpent,
    required this.remaining,
  });

  final double totalBudget;
  final double totalSpent;
  final double remaining;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pct = totalBudget > 0 ? (totalSpent / totalBudget).clamp(0.0, 1.0) : 0.0;
    final progressColor = pct >= 1.0
        ? scheme.error
        : pct >= 0.8
            ? Color.lerp(scheme.primary, scheme.error, 0.5)!
            : scheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text.rich(
              TextSpan(
                text: '月预算 ',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: scheme.onSurfaceVariant,
                ),
                children: [
                  TextSpan(
                    text: '¥${totalBudget.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            Text.rich(
              TextSpan(
                text: '剩余 ',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: scheme.onSurfaceVariant,
                ),
                children: [
                  TextSpan(
                    text: '¥${remaining.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: remaining >= 0 ? scheme.tertiary : scheme.error,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: pct.clamp(0.0, 1.0),
            minHeight: 4,
            backgroundColor: scheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
          ),
        ),
      ],
    );
  }
}
