import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../app/design_tokens.dart';
import '../../../../app/theme.dart';
import '../../domain/parse_result.dart';

/// Callback when user taps a field on the confirmation card.
typedef FieldTapCallback = void Function(String fieldName, dynamic currentValue);

/// Displays a parsed transaction for user confirmation with animated entry,
/// a source badge, and visual cues for missing fields.
class ConfirmationCard extends StatefulWidget {
  final ParseResult result;
  final FieldTapCallback? onFieldTap;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;

  const ConfirmationCard({
    super.key,
    required this.result,
    this.onFieldTap,
    this.onConfirm,
    this.onCancel,
  });

  @override
  State<ConfirmationCard> createState() => _ConfirmationCardState();
}

class _ConfirmationCardState extends State<ConfirmationCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entryController;
  late final Animation<double> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: AppDuration.normal,
    );
    _slideAnimation = Tween<double>(begin: 40, end: 0).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOut),
    );
    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _entryController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value),
          child: Opacity(opacity: _fadeAnimation.value, child: child),
        );
      },
      child: _buildCard(context),
    );
  }

  Widget _buildCard(BuildContext context) {
    final theme = Theme.of(context);
    final txColors = transactionColorsOrFallback(theme);
    final result = widget.result;

    return Card(
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.cardAll),
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SourceBadge(source: result.source, confidence: result.confidence),
            const SizedBox(height: AppSpacing.sm),
            _AmountRow(
              amount: result.amount,
              type: result.type,
              txColors: txColors,
              theme: theme,
              isMissing: result.amount == null,
              onTap: () =>
                  widget.onFieldTap?.call('amount', result.amount),
              onTypeChanged: (newType) =>
                  widget.onFieldTap?.call('type', newType),
            ),
            const SizedBox(height: AppSpacing.md),
            _FieldRow(
              icon: Icons.category_rounded,
              label: '分类',
              value: result.category ??
                  (result.type.toUpperCase() == 'TRANSFER' ? '转账' : '未识别'),
              isMissing: result.category == null &&
                  result.type.toUpperCase() != 'TRANSFER',
              onTap: () =>
                  widget.onFieldTap?.call('category', result.category),
            ),
            _FieldRow(
              icon: Icons.calendar_today_rounded,
              label: '日期',
              value: _formatDate(result.date),
              onTap: () => widget.onFieldTap?.call('date', result.date),
            ),
            if (result.description != null && result.description!.isNotEmpty)
              _FieldRow(
                icon: Icons.notes_rounded,
                label: '备注',
                value: result.description!,
                onTap: () => widget.onFieldTap
                    ?.call('description', result.description),
              ),
            _FieldRow(
              icon: Icons.account_balance_wallet_rounded,
              label: '账户',
              value: result.account ?? '默认账户',
              onTap: () =>
                  widget.onFieldTap?.call('account', result.account),
            ),
            const SizedBox(height: AppSpacing.lg),
            _ActionRow(
              onConfirm: widget.onConfirm,
              onCancel: widget.onCancel,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '今天';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final target = DateTime(date.year, date.month, date.day);
      final diff = today.difference(target).inDays;

      if (diff == 0) return '今天';
      if (diff == 1) return '昨天';
      if (diff == 2) return '前天';
      return DateFormat('M月d日').format(date);
    } catch (_) {
      return dateStr;
    }
  }
}

/// Badge showing where the parse result came from (local NLP / AI).
class _SourceBadge extends StatelessWidget {
  final ParseSource source;
  final double confidence;

  const _SourceBadge({required this.source, required this.confidence});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLocal = source == ParseSource.local;
    final label = isLocal ? '本地识别' : 'AI 识别';
    final icon = isLocal ? Icons.phone_android_rounded : Icons.auto_awesome_rounded;
    final scheme = theme.colorScheme;
    final txColors = theme.extension<TransactionColors>();
    final color = isLocal ? scheme.onSurfaceVariant : (txColors?.income ?? scheme.tertiary);

    final confidenceLabel = confidence >= 0.8
        ? '高'
        : (confidence >= 0.5 ? '中' : '低');

    return Semantics(
      label: '$label，置信度$confidenceLabel',
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(color: color),
          ),
          if (confidence > 0) ...[
            const SizedBox(width: AppSpacing.sm),
            _ConfidenceDots(confidence: confidence, color: color),
          ],
          const Spacer(),
        ],
      ),
    );
  }
}

/// 1–3 dots representing confidence level.
class _ConfidenceDots extends StatelessWidget {
  final double confidence;
  final Color color;

  const _ConfidenceDots({required this.confidence, required this.color});

  @override
  Widget build(BuildContext context) {
    final filled = confidence >= 0.8 ? 3 : (confidence >= 0.5 ? 2 : 1);
    return Row(
      children: List.generate(3, (i) {
        return Padding(
          padding: const EdgeInsets.only(right: 2),
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < filled
                  ? color
                  : color.withValues(alpha: 0.2),
            ),
          ),
        );
      }),
    );
  }
}

class _AmountRow extends StatelessWidget {
  final double? amount;
  final String type;
  final TransactionColors txColors;
  final ThemeData theme;
  final bool isMissing;
  final VoidCallback? onTap;
  final ValueChanged<String>? onTypeChanged;

  const _AmountRow({
    required this.amount,
    required this.type,
    required this.txColors,
    required this.theme,
    this.isMissing = false,
    this.onTap,
    this.onTypeChanged,
  });

  Color _colorOf(String t) {
    return switch (t) {
      'INCOME' => txColors.income,
      'TRANSFER' => txColors.transfer,
      _ => txColors.expense,
    };
  }

  String _labelOf(String t) {
    return switch (t) {
      'INCOME' => '收入',
      'TRANSFER' => '转账',
      _ => '支出',
    };
  }

  void _cycleType() {
    final next = switch (type) {
      'EXPENSE' => 'INCOME',
      'INCOME' => 'TRANSFER',
      _ => 'EXPENSE',
    };
    onTypeChanged?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    final typeColor = _colorOf(type);
    final expense = theme.extension<TransactionColors>()?.expense ?? theme.colorScheme.error;
    final amountColor = isMissing ? expense : typeColor;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: '交易类型：${_labelOf(type)}，点击切换',
            child: InkWell(
              onTap: _cycleType,
              borderRadius: AppRadius.smAll,
              child: AnimatedContainer(
                duration: AppDuration.fast,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.12),
                  borderRadius: AppRadius.smAll,
                  border: Border.all(
                    color: typeColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _labelOf(type),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: typeColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.swap_vert_rounded,
                      size: 12,
                      color: typeColor,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Spacer(),
          Semantics(
            button: true,
            label: isMissing
                ? '金额未填写，点击输入'
                : '金额 ${amount!.toStringAsFixed(2)} 元，点击修改',
            child: InkWell(
              onTap: onTap,
              borderRadius: AppRadius.mdAll,
              child: Text(
                isMissing ? '点击输入金额' : '¥${amount!.toStringAsFixed(2)}',
                style: isMissing
                    ? theme.textTheme.bodyMedium?.copyWith(
                        color: amountColor,
                        fontStyle: FontStyle.italic,
                      )
                    : theme.textTheme.headlineMedium?.copyWith(
                        color: amountColor,
                        fontWeight: FontWeight.w600,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isMissing;
  final VoidCallback? onTap;

  const _FieldRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isMissing = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final expense = theme.extension<TransactionColors>()?.expense ?? scheme.error;
    final valueColor = isMissing ? expense : scheme.onSurface;
    final labelColor = isMissing ? expense : scheme.onSurfaceVariant;

    return Semantics(
      button: true,
      label: isMissing
          ? '$label 未识别，点击选择'
          : '$label：$value，点击修改',
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.mdAll,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            children: [
              Icon(
                icon,
                size: AppIconSize.sm,
                color: labelColor,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: labelColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    const Spacer(),
                    Flexible(
                      child: Text(
                        value,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        textAlign: TextAlign.end,
                        style: isMissing
                            ? theme.textTheme.bodyMedium?.copyWith(
                                color: valueColor,
                                fontStyle: FontStyle.italic,
                              )
                            : theme.textTheme.bodyMedium?.copyWith(
                                color: valueColor,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(
                Icons.chevron_right_rounded,
                size: AppIconSize.sm,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;

  const _ActionRow({this.onConfirm, this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: onCancel == null
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    onCancel!();
                  },
            child: const Text('取消'),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          flex: 2,
          child: FilledButton.icon(
            onPressed: onConfirm == null
                ? null
                : () {
                    HapticFeedback.lightImpact();
                    onConfirm!();
                  },
            icon: const Icon(Icons.check_rounded),
            label: const Text('确认记账'),
          ),
        ),
      ],
    );
  }
}
