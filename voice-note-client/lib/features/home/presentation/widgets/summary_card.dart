import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/design_tokens.dart';
import '../../../budget/presentation/providers/budget_providers.dart';

// Design spec: 92% width, 16dp margin, 16dp radius, gradient #F0F7FF→#F5F8FF,
// backdrop blur, shadow #0057D9 8% 0/2 12/0; padding 24v 20h.
// Top: "X月支出" + eye (toggle amount visibility); right: 统计 pill.
// Hero: ¥ + integer 36sp w700 #1677FF, decimals 24sp w600 baseline-aligned.
// Income/balance 2-col grid; budget block (no ring): unset vs set states.

abstract final class _Spec {
  static const Color title = Color(0xFF333333);
  static const Color eyeDefault = Color(0xFF666666);
  static const Color eyeActive = Color(0xFF1677FF);
  static const Color statsBg = Color(0xFFE8F3FF);
  static const Color statsText = Color(0xFF1677FF);
  static const Color heroAmount = Color(0xFF1677FF);
  static const Color labelSecondary = Color(0xFF666666);
  static const Color incomeAmount = Color(0xFFFF9500);
  static const Color balancePositive = Color(0xFF00B42A);
  static const Color balanceNegative = Color(0xFFF53F3F);
  static const Color budgetUnsetBg = Color(0xFFF5F7FA);
  static const Color budgetUnsetHint = Color(0xFF999999);
  static const Color budgetLink = Color(0xFF1677FF);
  static const Color progressTrack = Color(0xFFE8EDF3);
  static const Color progressNormal = Color(0xFF1677FF);
  static const Color progressWarn = Color(0xFFFF9500);
  static const Color progressOver = Color(0xFFF53F3F);
  static const Color shadowColor = Color(0x140057D9); // 8%
}

/// Card: monthly expense hero, income/balance, budget block. All behavior preserved.
class SummaryCard extends ConsumerStatefulWidget {
  const SummaryCard({
    super.key,
    required this.monthLabel,
    required this.totalIncome,
    required this.totalExpense,
  });

  final String monthLabel;
  final double totalIncome;
  final double totalExpense;

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
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: _Spec.shadowColor,
                offset: Offset(0, 2),
                blurRadius: 12,
                spreadRadius: 0,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFF0F7FF), Color(0xFFF5F8FF)],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTopRow(context),
                    const SizedBox(height: 8),
                    _buildDetailSettingsRow(context),
                    const SizedBox(height: 12),
                    _buildHeroAmount(context),
                    const SizedBox(height: 20),
                    _buildIncomeBalance(context),
                    const SizedBox(height: 16),
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
                      error: (_, __) => _BudgetUnsetBlock(onTap: () => context.push('/settings/budget')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopRow(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${widget.monthLabel}支出',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: _Spec.title,
              ),
            ),
            const SizedBox(width: 6),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _amountsVisible = !_amountsVisible),
                borderRadius: BorderRadius.circular(22),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                    child: Icon(
                      _amountsVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      size: 14,
                      color: _amountsVisible ? _Spec.eyeDefault : _Spec.eyeActive,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        Material(
          color: _Spec.statsBg,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: () => context.push('/statistics'),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.bar_chart_outlined, size: 14, color: _Spec.statsText),
                    const SizedBox(width: 4),
                    Text(
                      '统计',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: _Spec.statsText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailSettingsRow(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _cardNavChip(
          context,
          icon: Icons.receipt_long_outlined,
          label: '明细',
          onTap: () => context.push('/transactions'),
        ),
        const SizedBox(width: 8),
        _cardNavChip(
          context,
          icon: Icons.settings_outlined,
          label: '设置',
          onTap: () => context.push('/settings'),
        ),
      ],
    );
  }

  Widget _cardNavChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: _Spec.statsBg,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: _Spec.statsText),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _Spec.statsText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroAmount(BuildContext context) {
    final expense = widget.totalExpense;
    final str = expense.toStringAsFixed(2);
    final dot = str.indexOf('.');
    final intPart = dot > 0 ? str.substring(0, dot) : str;
    final decPart = dot > 0 ? str.substring(dot) : '';

    if (!_amountsVisible) {
      return Text(
        '¥****',
        style: TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.w700,
          color: _Spec.heroAmount,
          height: 1.15,
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          '¥$intPart',
          style: const TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w700,
            color: _Spec.heroAmount,
            height: 1.15,
          ),
        ),
        if (decPart.isNotEmpty)
          Text(
            decPart,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: _Spec.heroAmount,
              height: 1.2,
            ),
          ),
      ],
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
        const SizedBox(width: 32),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: _Spec.labelSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          display,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: color,
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
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '月预算',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: _Spec.labelSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '暂未设置',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: _Spec.budgetUnsetHint,
                    ),
                  ),
                ],
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '点击设置',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: _Spec.budgetLink,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.edit_outlined, size: 12, color: _Spec.budgetLink),
                  ],
                ),
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
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text.rich(
              TextSpan(
                text: '月预算 ',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: _Spec.labelSecondary,
                ),
                children: [
                  TextSpan(
                    text: '¥${totalBudget.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            Text.rich(
              TextSpan(
                text: '剩余 ',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: _Spec.labelSecondary,
                ),
                children: [
                  TextSpan(
                    text: '¥${remaining.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: pct.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: _Spec.progressTrack,
            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
          ),
        ),
      ],
    );
  }
}
