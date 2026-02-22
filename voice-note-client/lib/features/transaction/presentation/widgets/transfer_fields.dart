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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<TransferDirection>(
          segments: const [
            ButtonSegment(
              value: TransferDirection.outbound,
              label: Text('转出'),
              icon: Icon(Icons.arrow_forward),
            ),
            ButtonSegment(
              value: TransferDirection.inbound,
              label: Text('转入'),
              icon: Icon(Icons.arrow_back),
            ),
          ],
          selected: {widget.direction ?? TransferDirection.outbound},
          onSelectionChanged: (set) => widget.onDirectionChanged(set.first),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          focusNode: _counterpartyFocusNode,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: '对方 (可选)',
            hintText: '账户名或人名',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          controller: _controller,
          onChanged: (v) => widget.onCounterpartyChanged(v.isEmpty ? null : v),
          onSubmitted: (_) => FocusScope.of(context).unfocus(),
        ),
      ],
    );
  }
}
