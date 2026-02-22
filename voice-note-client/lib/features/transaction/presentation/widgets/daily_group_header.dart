import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/date_extensions.dart';

// 与参考图一致：两行（日期+箭头 / 支出|收入），右侧装饰图标；可点击进入当日明细。
const _kPaddingV = 12.0;
const _kDateFontSize = 16.0;
const _kDateColor = Color(0xFF333333);
const _kDateFontWeight = FontWeight.w600;
const _kAmountFontSize = 13.0;
const _kAmountColor = Color(0xFF666666);
const _kArrowColor = Color(0xFF999999);
const _kReceiptBg = Color(0xFFFFF8E1);
const _kReceiptRed = Color(0xFFE53935);
const _kSparkleColor = Color(0xFFFF7043);

const _weekdays = ['一', '二', '三', '四', '五', '六', '日'];

/// Header for a daily transaction group: date line + expense|income line, optional tap to day detail.
class DailyGroupHeader extends StatelessWidget {
  const DailyGroupHeader({
    super.key,
    required this.date,
    required this.dailyIncome,
    required this.dailyExpense,
  });

  final DateTime date;
  final double dailyIncome;
  final double dailyExpense;

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
    return NumberFormat.currency(locale: 'zh_CN', symbol: '¥', decimalDigits: 2).format(v);
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
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
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
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.chevron_right,
                            size: 20,
                            color: _kArrowColor,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '支出$expenseStr | 收入$incomeStr',
                        style: const TextStyle(
                          fontSize: _kAmountFontSize,
                          fontWeight: FontWeight.w400,
                          color: _kAmountColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _DailyReceiptDecoration(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 右侧装饰：浅黄圆角底 + 红色收据¥图标 + 红橙星爆。
class _DailyReceiptDecoration extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _kReceiptBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: _kReceiptRed,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Center(
                    child: Text(
                      '¥',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 2,
            child: Icon(Icons.auto_awesome, size: 12, color: _kSparkleColor),
          ),
          Positioned(
            left: 6,
            top: 0,
            child: Icon(Icons.auto_awesome, size: 8, color: _kSparkleColor),
          ),
          Positioned(
            right: 4,
            bottom: 8,
            child: Icon(Icons.auto_awesome, size: 10, color: _kSparkleColor),
          ),
        ],
      ),
    );
  }
}
