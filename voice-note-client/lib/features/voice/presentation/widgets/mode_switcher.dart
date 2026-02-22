import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme.dart';

/// Voice input mode.
enum VoiceInputMode {
  /// VAD-based automatic speech detection.
  auto,

  /// Press and hold to speak.
  pushToTalk,

  /// Text keyboard input.
  keyboard,
}

/// Enterprise-style segmented control: compact, neutral surface, clear selected state.
class ModeSwitcher extends StatelessWidget {
  final VoiceInputMode mode;
  final ValueChanged<VoiceInputMode> onChanged;
  final bool hideAutoMode;

  const ModeSwitcher({
    super.key,
    required this.mode,
    required this.onChanged,
    this.hideAutoMode = false,
  });

  static const _height = 40.0;
  static const _radius = 10.0;
  static const _iconSize = 18.0;
  static const _fontSize = 13.0;

  @override
  Widget build(BuildContext context) {
    final segments = hideAutoMode
        ? [VoiceInputMode.pushToTalk, VoiceInputMode.keyboard]
        : [VoiceInputMode.auto, VoiceInputMode.pushToTalk, VoiceInputMode.keyboard];

    return Semantics(
      label: '输入模式：${_label(mode)}',
      child: Container(
        height: _height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_radius),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D000000),
              offset: Offset(0, 1),
              blurRadius: 3,
            ),
          ],
        ),
        child: Row(
          children: [
            for (var i = 0; i < segments.length; i++) ...[
              if (i > 0)
                Container(
                  width: 1,
                  height: 20,
                  color: const Color(0xFFE5E7EB),
                ),
              Expanded(
                child: _Segment(
                  value: segments[i],
                  label: _label(segments[i]),
                  icon: _icon(segments[i]),
                  selected: mode == segments[i],
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onChanged(segments[i]);
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _label(VoiceInputMode m) => switch (m) {
        VoiceInputMode.auto => '自动',
        VoiceInputMode.pushToTalk => '手动',
        VoiceInputMode.keyboard => '键盘',
      };

  IconData _icon(VoiceInputMode m) => switch (m) {
        VoiceInputMode.auto => Icons.auto_mode_rounded,
        VoiceInputMode.pushToTalk => Icons.touch_app_rounded,
        VoiceInputMode.keyboard => Icons.keyboard_rounded,
      };
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.value,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final VoiceInputMode value;
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.brandPrimary : AppColors.textSecondary;
    return Material(
      color: selected
          ? AppColors.brandPrimary.withValues(alpha: 0.08)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(ModeSwitcher._radius - 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ModeSwitcher._radius - 2),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: ModeSwitcher._iconSize,
                color: color,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: ModeSwitcher._fontSize,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: color,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
