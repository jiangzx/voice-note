import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/design_tokens.dart';
import '../../../budget/presentation/providers/budget_providers.dart';

// Enterprise-style: compact, neutral surface, clear hierarchy, 4px grid.

abstract final class _Spec {
  static const double cardRadius = 12;
  static const Color surface = Color(0xFFFAFBFC);
  static const Color border = Color(0xFFE5E7EB);
  static const Color title = Color(0xFF6B7280);
  static const Color eyeDefault = Color(0xFF9CA3AF);
  static const Color eyeActive = Color(0xFF2563EB);
  static const Color statsBg = Color(0xFFF3F4F6);
  static const Color statsText = Color(0xFF374151);
  static const Color heroAmount = Color(0xFF000000);
  static const Color labelSecondary = Color(0xFF6B7280);
  static const Color incomeAmount = Color(0xFFD4A017);
  static const Color balancePositive = Color(0xFF059669);
  static const Color balanceNegative = Color(0xFFDC2626);
  static const Color budgetUnsetBg = Color(0xFFF9FAFB);
  static const Color budgetUnsetHint = Color(0xFF9CA3AF);
  static const Color budgetLink = Color(0xFF2563EB);
  static const Color progressTrack = Color(0xFFE5E7EB);
  static const Color progressNormal = Color(0xFF2563EB);
  static const Color progressWarn = Color(0xFFD97706);
  static const Color progressOver = Color(0xFFDC2626);
  static const Color shadowColor = Color(0x0D000000);
}

/// Card: monthly expense hero, income/balance, budget block. All behavior preserved.
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
            color: _Spec.surface,
            borderRadius: BorderRadius.circular(_Spec.cardRadius),
            border: Border.all(color: _Spec.border, width: 1),
            boxShadow: const [
              BoxShadow(
                color: _Spec.shadowColor,
                offset: Offset(0, 1),
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
                _buildTopRow(context),
                const SizedBox(height: 10),
                _buildHeroAmount(context),
                const SizedBox(height: 14),
                _buildIncomeBalance(context),
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

  Widget _buildTopRow(BuildContext context) {
    final monthLabelChild = Text(
      '${widget.monthLabel}支出',
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: _Spec.title,
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
                      color: _amountsVisible ? _Spec.eyeDefault : _Spec.eyeActive,
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
              color: _Spec.statsBg,
              borderRadius: BorderRadius.circular(6),
              child: InkWell(
                onTap: () => context.push('/statistics'),
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bar_chart_outlined, size: 16, color: _Spec.statsText),
                      SizedBox(width: 4),
                      Text(
                        '统计',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: _Spec.statsText,
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
                child: const SizedBox(
                  width: 36,
                  height: 36,
                  child: Center(
                    child: Icon(Icons.settings_outlined, size: 20, color: _Spec.statsText),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeroAmount(BuildContext context) {
    final expense = widget.totalExpense;
    final str = expense.toStringAsFixed(2);
    final dot = str.indexOf('.');
    final intPart = dot > 0 ? str.substring(0, dot) : str;
    final decPart = dot > 0 ? str.substring(dot) : '';

    final amountContent = !_amountsVisible
        ? const Text(
            '¥****',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: _Spec.heroAmount,
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
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: _Spec.heroAmount,
                  height: 1.2,
                  letterSpacing: -0.5,
                ),
              ),
              if (decPart.isNotEmpty)
                Text(
                  decPart,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: _Spec.heroAmount,
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

  Widget _buildIncomeBalance(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _LabelAmount(
            label: '收入',
            amount: widget.totalIncome,
            visible: _amountsVisible,
            color: _Spec.incomeAmount,
            showSign: false,
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: _LabelAmount(
            label: '结余',
            amount: _balance,
            visible: _amountsVisible,
            color: _balance >= 0 ? _Spec.balancePositive : _Spec.balanceNegative,
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
    final sign = showSign && amount != 0 ? (amount >= 0 ? '+' : '-') : '';
    final absAmount = amount.abs();
    final display = visible ? '$sign¥${absAmount.toStringAsFixed(2)}' : '¥****';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: _Spec.labelSecondary,
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
    return Material(
      color: _Spec.budgetUnsetBg,
      borderRadius: BorderRadius.circular(_Spec.cardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_Spec.cardRadius),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '月预算',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _Spec.labelSecondary,
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
                      color: _Spec.budgetUnsetHint,
                    ),
                  ),
                  SizedBox(width: 4),
                  Text(
                    '设置',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _Spec.budgetLink,
                    ),
                  ),
                  SizedBox(width: 2),
                  Icon(Icons.arrow_forward_ios, size: 10, color: _Spec.budgetLink),
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
    final pct = totalBudget > 0 ? (totalSpent / totalBudget).clamp(0.0, 1.0) : 0.0;
    final progressColor = pct >= 1.0
        ? _Spec.progressOver
        : pct >= 0.8
            ? _Spec.progressWarn
            : _Spec.progressNormal;

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
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _Spec.labelSecondary,
                ),
                children: [
                  TextSpan(
                    text: '¥${totalBudget.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _Spec.heroAmount,
                    ),
                  ),
                ],
              ),
            ),
            Text.rich(
              TextSpan(
                text: '剩余 ',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _Spec.labelSecondary,
                ),
                children: [
                  TextSpan(
                    text: '¥${remaining.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: remaining >= 0 ? _Spec.balancePositive : _Spec.balanceNegative,
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
            backgroundColor: _Spec.progressTrack,
            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
          ),
        ),
      ],
    );
  }
}
