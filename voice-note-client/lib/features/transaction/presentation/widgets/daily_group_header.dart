import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/date_extensions.dart';

// Enterprise-style: compact date header, neutral palette, clear hierarchy.
const _kPaddingV = 8.0;
const _kDateFontSize = 13.0;
const _kDateColor = Color(0xFF374151);
const _kDateFontWeight = FontWeight.w500;
const _kDateLetterSpacing = 0.2;
const _kAmountFontSize = 11.0;
const _kAmountColor = Color(0xFF6B7280);
const _kArrowColor = Color(0xFF9CA3AF);
const _kReceiptBg = Color(0xFFF3F4F6);
const _kReceiptFg = Color(0xFF6B7280);

const _weekdays = ['一', '二', '三', '四', '五', '六', '日'];

/// Header for a daily transaction group: date line + expense|income line, optional tap to day detail.
class DailyGroupHeader extends StatelessWidget {
  const DailyGroupHeader({
    super.key,
    required this.date,
    required this.dailyIncome,
    required this.dailyExpense,
    this.showReceiptIcon = false,
  });

  final DateTime date;
  final double dailyIncome;
  final double dailyExpense;
  /// When true, shows receipt icon on the right (e.g. home recent list only).
  final bool showReceiptIcon;

  String _label(DateTime today) {
    if (date.isSameDay(today)) return '今天';
    if (date.isSameDay(today.yesterday)) return '昨天';
    if (date.isSameWeek(today)) return '本周';
    return '更早';
  }

  String _dateSuffix() {
    return '${date.month}月${date.day}日 (周${_weekdays[date.weekday - 1]})';
  }

  String _formatMoney(double v) {
    return NumberFormat.currency(
      locale: 'zh_CN',
      symbol: '¥',
      decimalDigits: 2,
    ).format(v);
  }

  void _onTap(BuildContext context) {
    final from = DateTime(date.year, date.month, date.day);
    final to = DateTime(date.year, date.month, date.day, 23, 59, 59);
    final fromStr = DateFormat('yyyy-MM-dd').format(from);
    final toStr = DateFormat('yyyy-MM-dd').format(to);
    context.push('/transactions?dateFrom=$fromStr&dateTo=$toStr');
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now().toDateOnly;
    final label = _label(today);
    final dateSuffix = _dateSuffix();
    final expenseStr = _formatMoney(dailyExpense);
    final incomeStr = _formatMoney(dailyIncome);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: _kPaddingV),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onTap(context),
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$label $dateSuffix',
                            style: const TextStyle(
                              fontSize: _kDateFontSize,
                              fontWeight: _kDateFontWeight,
                              color: _kDateColor,
                              letterSpacing: _kDateLetterSpacing,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.chevron_right,
                            size: 18,
                            color: _kArrowColor,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '支出$expenseStr · 收入$incomeStr',
                        style: const TextStyle(
                          fontSize: _kAmountFontSize,
                          fontWeight: FontWeight.w400,
                          color: _kAmountColor,
                        ),
                      ),
                    ],
                  ),
                ),
                if (showReceiptIcon) ...[
                  const SizedBox(width: 12),
                  const _DailyReceiptDecoration(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Right decoration: subtle chip with receipt icon (home list only).
class _DailyReceiptDecoration extends StatelessWidget {
  const _DailyReceiptDecoration();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: _kReceiptBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(
        Icons.receipt_long_outlined,
        size: 18,
        color: _kReceiptFg,
      ),
    );
  }
}
