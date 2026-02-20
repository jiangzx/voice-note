import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../app/design_tokens.dart';
import '../../../../app/theme.dart';
import '../../domain/draft_batch.dart';
import '../../domain/parse_result.dart';

typedef BatchItemCallback = void Function(int index);

/// Displays a batch of parsed transactions for user confirmation.
///
/// Uses [DraftBatch] to render each item with status indicators and
/// provides bulk confirm/cancel actions. When [isLoading] is true,
/// pending rows show a shimmer effect to indicate LLM processing.
class BatchConfirmationCard extends StatefulWidget {
  final DraftBatch batch;
  final bool isLoading;
  final BatchItemCallback? onConfirmItem;
  final BatchItemCallback? onCancelItem;
  final VoidCallback? onConfirmAll;
  final VoidCallback? onCancelAll;

  const BatchConfirmationCard({
    super.key,
    required this.batch,
    this.isLoading = false,
    this.onConfirmItem,
    this.onCancelItem,
    this.onConfirmAll,
    this.onCancelAll,
  });

  @override
  State<BatchConfirmationCard> createState() => _BatchConfirmationCardState();
}

class _BatchConfirmationCardState extends State<BatchConfirmationCard>
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
    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _entryController, curve: Curves.easeOut));
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
      builder: (context, child) => Transform.translate(
        offset: Offset(0, _slideAnimation.value),
        child: Opacity(opacity: _fadeAnimation.value, child: child),
      ),
      child: _buildCard(context),
    );
  }

  Widget _buildCard(BuildContext context) {
    final theme = Theme.of(context);
    final batch = widget.batch;

    return Card(
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.xlAll),
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _BatchHeader(batch: batch),
            const SizedBox(height: AppSpacing.sm),
            _buildItemList(theme, batch),
            const SizedBox(height: AppSpacing.sm),
            _SummaryBar(batch: batch),
            const SizedBox(height: AppSpacing.lg),
            _BatchActionRow(
              hasPending: batch.pendingCount > 0,
              isLoading: widget.isLoading,
              onConfirmAll: widget.onConfirmAll,
              onCancelAll: widget.onCancelAll,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemList(ThemeData theme, DraftBatch batch) {
    final items = batch.items;
    final onConfirmItem = widget.onConfirmItem;
    final onCancelItem = widget.onCancelItem;
    
    // Use ListView.builder for long lists to improve performance
    if (items.length > 3) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: _maxBatchListHeight),
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: items.length,
          itemBuilder: (context, i) => _BatchItemRow(
            item: items[i],
            displayIndex: i + 1,
            isLoading:
                widget.isLoading && items[i].status == DraftStatus.pending,
            onConfirmItem: onConfirmItem,
            onCancelItem: onCancelItem,
          ),
        ),
      );
    }
    
    // Use Column for short lists (≤3 items) for simpler structure
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < items.length; i++)
          _BatchItemRow(
            item: items[i],
            displayIndex: i + 1,
            isLoading:
                widget.isLoading && items[i].status == DraftStatus.pending,
            onConfirmItem: onConfirmItem,
            onCancelItem: onCancelItem,
          ),
      ],
    );
  }
  
  static const double _maxBatchListHeight = 240.0;
}

// ======================== Header ========================

class _BatchHeader extends StatelessWidget {
  final DraftBatch batch;
  const _BatchHeader({required this.batch});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasLlm = batch.items.any((t) => t.result.source == ParseSource.llm);
    final sourceLabel = hasLlm ? 'AI 识别' : '本地识别';
    final sourceIcon = hasLlm
        ? Icons.auto_awesome_rounded
        : Icons.phone_android_rounded;
    final sourceColor = hasLlm
        ? theme.colorScheme.tertiary
        : theme.colorScheme.outline;

    return Row(
      children: [
        Icon(sourceIcon, size: 14, color: sourceColor),
        const SizedBox(width: AppSpacing.xs),
        Text(
          sourceLabel,
          style: theme.textTheme.labelSmall?.copyWith(color: sourceColor),
        ),
        const SizedBox(width: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: AppRadius.smAll,
          ),
          child: Semantics(
            liveRegion: true,
            label: '${batch.pendingCount}笔待确认',
            child: Text(
              '${batch.pendingCount} 笔待确认',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ),
        const Spacer(),
        Text(
          '共 ${batch.length} 笔',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    );
  }
}

// ======================== Item Row ========================

class _BatchItemRow extends StatelessWidget {
  final DraftTransaction item;
  final int displayIndex;
  final bool isLoading;
  final BatchItemCallback? onConfirmItem;
  final BatchItemCallback? onCancelItem;

  const _BatchItemRow({
    required this.item,
    required this.displayIndex,
    this.isLoading = false,
    this.onConfirmItem,
    this.onCancelItem,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final txColors = theme.extension<TransactionColors>()!;
    final result = item.result;
    final status = item.status;

    final isCancelled = status == DraftStatus.cancelled;
    final isConfirmed = status == DraftStatus.confirmed;
    final isResolved = isCancelled || isConfirmed;

    final bgColor = isConfirmed
        ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4)
        : isCancelled
        ? theme.colorScheme.errorContainer.withValues(alpha: 0.3)
        : Colors.transparent;

    final textOpacity = isCancelled ? 0.5 : 1.0;

    final typeColor = switch (result.type.toUpperCase()) {
      'INCOME' => txColors.income,
      'TRANSFER' => txColors.transfer,
      _ => txColors.expense,
    };
    
    // Apply opacity to colors instead of using Opacity widget for better performance
    final outlineColor = theme.colorScheme.outline.withValues(alpha: textOpacity);
    final onSurfaceColor = theme.colorScheme.onSurface.withValues(alpha: textOpacity);
    final typeColorWithOpacity = typeColor.withValues(alpha: textOpacity);

    final typeLabel = switch (result.type.toUpperCase()) {
      'INCOME' => '收入',
      'TRANSFER' => '转账',
      _ => '支出',
    };

    final amountStr = result.amount != null
        ? '¥${result.amount!.toStringAsFixed(2)}'
        : '¥--';

    return Semantics(
      label:
          '第$displayIndex笔，${result.category ?? ""}$typeLabel'
          '${result.amount?.toStringAsFixed(2) ?? ""}元'
          '${isConfirmed
              ? "，已确认"
              : isCancelled
              ? "，已取消"
              : "，待确认"}',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: AppRadius.mdAll,
        ),
        child: Dismissible(
          key: ValueKey('batch-item-${item.index}'),
          direction: isResolved || isLoading
              ? DismissDirection.none
              : DismissDirection.horizontal,
          confirmDismiss: (direction) async {
            HapticFeedback.selectionClick();
            if (direction == DismissDirection.endToStart) {
              onCancelItem?.call(item.index);
            } else {
              onConfirmItem?.call(item.index);
            }
            return false;
          },
          background: _swipeBackground(
            alignment: Alignment.centerLeft,
            color: theme.colorScheme.primaryContainer,
            icon: Icons.check_rounded,
          ),
          secondaryBackground: _swipeBackground(
            alignment: Alignment.centerRight,
            color: theme.colorScheme.errorContainer,
            icon: Icons.delete_outline_rounded,
          ),
          child: _maybeShimmer(
            isLoading: isLoading,
            theme: theme,
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: Text(
                    '$displayIndex',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: outlineColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.12 * textOpacity),
                    borderRadius: AppRadius.smAll,
                  ),
                  child: Text(
                    typeLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: typeColorWithOpacity,
                      fontWeight: FontWeight.w600,
                      decoration: isCancelled
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    '${result.category ?? ""}'
                    '${result.description != null ? " · ${result.description}" : ""}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: onSurfaceColor,
                      decoration: isCancelled
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  amountStr,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: typeColorWithOpacity,
                    fontWeight: FontWeight.w600,
                    decoration: isCancelled
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                _StatusIcon(status: status),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _maybeShimmer({
    required bool isLoading,
    required ThemeData theme,
    required Widget child,
  }) {
    if (!isLoading) return child;
    return Shimmer.fromColors(
      baseColor: theme.colorScheme.surfaceContainerHighest,
      highlightColor: theme.colorScheme.surface,
      child: child,
    );
  }

  Widget _swipeBackground({
    required Alignment alignment,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(color: color, borderRadius: AppRadius.mdAll),
      child: Icon(icon, color: Colors.white),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  final DraftStatus status;
  const _StatusIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, animation) =>
          ScaleTransition(scale: animation, child: child),
      child: switch (status) {
        DraftStatus.confirmed => Icon(
          Icons.check_circle_rounded,
          key: const ValueKey('confirmed'),
          size: AppIconSize.sm,
          color: theme.colorScheme.primary,
        ),
        DraftStatus.cancelled => Icon(
          Icons.cancel_rounded,
          key: const ValueKey('cancelled'),
          size: AppIconSize.sm,
          color: theme.colorScheme.error,
        ),
        DraftStatus.pending => const SizedBox(
          key: ValueKey('pending'),
          width: AppIconSize.sm,
          height: AppIconSize.sm,
        ),
      },
    );
  }
}

// ======================== Summary Bar ========================

class _SummaryBar extends StatelessWidget {
  final DraftBatch batch;
  const _SummaryBar({required this.batch});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pending = batch.pendingItems;
    final total = pending.fold(0.0, (sum, t) => sum + (t.result.amount ?? 0));
    final totalStr = total == total.roundToDouble()
        ? total.toInt().toString()
        : total.toStringAsFixed(2);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '待确认合计',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          Text(
            '¥$totalStr',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

// ======================== Action Row ========================

class _BatchActionRow extends StatelessWidget {
  final bool hasPending;
  final bool isLoading;
  final VoidCallback? onConfirmAll;
  final VoidCallback? onCancelAll;

  const _BatchActionRow({
    required this.hasPending,
    this.isLoading = false,
    this.onConfirmAll,
    this.onCancelAll,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = hasPending && !isLoading;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: enabled && onCancelAll != null
                ? () {
                    HapticFeedback.selectionClick();
                    onCancelAll!();
                  }
                : null,
            child: const Text('取消'),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          flex: 2,
          child: FilledButton.icon(
            onPressed: enabled && onConfirmAll != null
                ? () {
                    HapticFeedback.lightImpact();
                    onConfirmAll!();
                  }
                : null,
            icon: const Icon(Icons.check_rounded),
            label: const Text('全部确认'),
          ),
        ),
      ],
    );
  }
}
