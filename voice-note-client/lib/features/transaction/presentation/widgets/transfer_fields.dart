import 'package:flutter/material.dart';

import '../../../../app/design_tokens.dart';
import '../../domain/entities/transaction_entity.dart';

/// Transfer-specific fields: direction toggle and counterparty input.
class TransferFields extends StatefulWidget {
  const TransferFields({
    super.key,
    required this.direction,
    this.counterparty,
    required this.onDirectionChanged,
    required this.onCounterpartyChanged,
    this.onCounterpartyFocusChange,
  });

  final TransferDirection? direction;
  final String? counterparty;
  final ValueChanged<TransferDirection> onDirectionChanged;
  final ValueChanged<String?> onCounterpartyChanged;
  /// Called when the counterparty TextField gains or loses focus (for hiding custom keypad).
  final ValueChanged<bool>? onCounterpartyFocusChange;

  @override
  State<TransferFields> createState() => _TransferFieldsState();
}

class _TransferFieldsState extends State<TransferFields> {
  late final TextEditingController _controller;
  late final FocusNode _counterpartyFocusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.counterparty);
    _counterpartyFocusNode = FocusNode();
    _counterpartyFocusNode.addListener(_notifyFocusChange);
  }

  void _notifyFocusChange() {
    widget.onCounterpartyFocusChange?.call(_counterpartyFocusNode.hasFocus);
  }

  @override
  void didUpdateWidget(TransferFields oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.counterparty != widget.counterparty &&
        widget.counterparty != _controller.text) {
      _controller.text = widget.counterparty ?? '';
    }
  }

  @override
  void dispose() {
    _counterpartyFocusNode.removeListener(_notifyFocusChange);
    _counterpartyFocusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<TransferDirection>(
          segments: const [
            ButtonSegment(
              value: TransferDirection.outbound,
              label: Text('转出'),
              icon: Icon(Icons.arrow_forward_rounded, size: 16),
            ),
            ButtonSegment(
              value: TransferDirection.inbound,
              label: Text('转入'),
              icon: Icon(Icons.arrow_back_rounded, size: 16),
            ),
          ],
          selected: {widget.direction ?? TransferDirection.outbound},
          onSelectionChanged: (set) => widget.onDirectionChanged(set.first),
          style: const ButtonStyle(
            padding: WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
            ),
            minimumSize: WidgetStatePropertyAll(Size(0, 36)),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          focusNode: _counterpartyFocusNode,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: '对方 (可选)',
            hintText: '账户名或人名',
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
              ),
            ),
          ),
          controller: _controller,
          onChanged: (v) => widget.onCounterpartyChanged(v.isEmpty ? null : v),
          onSubmitted: (_) => FocusScope.of(context).unfocus(),
        ),
      ],
    );
  }
}
