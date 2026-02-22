import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/design_tokens.dart';

/// Controller for amount string input logic.
class AmountInputController {
  String _value = '0';

  static const int _maxDecimals = 2;
  static const double _maxAmount = 99999999.99;

  String get value => _value;

  /// Append a digit or decimal point character.
  void append(String char) {
    if (char == '.') {
      if (_value.contains('.')) return;
      _value = '$_value.';
      return;
    }

    final candidate = _value == '0' && char != '.' ? char : '$_value$char';

    // Enforce decimal limit
    final dotIndex = candidate.indexOf('.');
    if (dotIndex != -1 && candidate.length - dotIndex - 1 > _maxDecimals) {
      return;
    }

    // Enforce max value
    final parsed = double.tryParse(candidate);
    if (parsed == null || parsed > _maxAmount) return;

    _value = candidate;
  }

  /// Remove the last character.
  void backspace() {
    if (_value.length <= 1) {
      _value = '0';
      return;
    }
    _value = _value.substring(0, _value.length - 1);
  }

  /// Reset to zero.
  void clear() {
    _value = '0';
  }

  /// Set the value from a double (for editing mode).
  void setFromDouble(double amount) {
    if (amount == amount.truncateToDouble()) {
      _value = amount.toInt().toString();
    } else {
      _value = amount.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '');
    }
    if (_value.endsWith('.')) {
      _value = _value.substring(0, _value.length - 1);
    }
    if (_value.isEmpty) _value = '0';
  }

  /// Parse the current value as double.
  double toDouble() => double.tryParse(_value) ?? 0;
}

/// Custom 4x3 numeric keypad for amount input.
class NumberPad extends StatelessWidget {
  const NumberPad({super.key, required this.onKey, required this.onBackspace});

  final ValueChanged<String> onKey;
  final VoidCallback onBackspace;

  static const _keys = [
    '7',
    '8',
    '9',
    '4',
    '5',
    '6',
    '1',
    '2',
    '3',
    '.',
    '0',
    '⌫',
  ];

  /// Max fraction of screen height for the keypad (keeps it compact).
  static const double _maxHeightFraction = 0.28;
  /// Prefer flatter keys; raised if constrained to avoid overflow.
  static const double _baseChildAspectRatio = 2.5;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.sizeOf(context).height;
    final maxHeight = screenHeight * _maxHeightFraction;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final capHeight = constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : double.infinity;
          final effectiveMaxHeight = maxHeight < capHeight ? maxHeight : capHeight;
          final cellHeight = (w / 3) / _baseChildAspectRatio;
          final intrinsicHeight = 4 * cellHeight;
          final height = intrinsicHeight <= effectiveMaxHeight
              ? intrinsicHeight
              : effectiveMaxHeight;
          final aspectRatio = height <= intrinsicHeight
              ? _baseChildAspectRatio
              : (w / 3) * 4 / height;

          return SizedBox(
            height: height,
            child: GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: aspectRatio,
              children: _keys.map((key) {
                return _KeyButton(
                  label: key,
                  onTap: key == '⌫' ? onBackspace : () => onKey(key),
                  isBackspace: key == '⌫',
                  theme: theme,
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }
}

class _KeyButton extends StatelessWidget {
  const _KeyButton({
    required this.label,
    required this.onTap,
    required this.isBackspace,
    required this.theme,
  });

  final String label;
  final VoidCallback onTap;
  final bool isBackspace;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Center(
        child: isBackspace
            ? Icon(
                Icons.backspace_outlined,
                size: 24,
                color: theme.colorScheme.onSurface,
              )
            : Text(
                label,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
      ),
    );
  }
}
