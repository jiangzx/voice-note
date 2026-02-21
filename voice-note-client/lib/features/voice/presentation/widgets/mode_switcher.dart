import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/design_tokens.dart';

/// Voice input mode.
enum VoiceInputMode {
  /// VAD-based automatic speech detection.
  auto,

  /// Press and hold to speak.
  pushToTalk,

  /// Text keyboard input.
  keyboard,
}

/// Segmented control for switching between voice input modes.
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

  String _modeLabel(VoiceInputMode m) => switch (m) {
        VoiceInputMode.auto => '自动',
        VoiceInputMode.pushToTalk => '手动',
        VoiceInputMode.keyboard => '键盘',
      };

  static const _segmentAuto = ButtonSegment<VoiceInputMode>(
    value: VoiceInputMode.auto,
    icon: Icon(Icons.auto_mode_rounded, size: AppIconSize.sm),
    label: Text('自动'),
  );
  static const _segmentPushToTalk = ButtonSegment<VoiceInputMode>(
    value: VoiceInputMode.pushToTalk,
    icon: Icon(Icons.touch_app_rounded, size: AppIconSize.sm),
    label: Text('手动'),
  );
  static const _segmentKeyboard = ButtonSegment<VoiceInputMode>(
    value: VoiceInputMode.keyboard,
    icon: Icon(Icons.keyboard_rounded, size: AppIconSize.sm),
    label: Text('键盘'),
  );

  @override
  Widget build(BuildContext context) {
    final segments = hideAutoMode
        ? const [_segmentPushToTalk, _segmentKeyboard]
        : const [_segmentAuto, _segmentPushToTalk, _segmentKeyboard];
    return Semantics(
      label: '输入模式：当前为${_modeLabel(mode)}',
      child: SegmentedButton<VoiceInputMode>(
      segments: segments,
      selected: {mode},
      onSelectionChanged: (selected) {
        HapticFeedback.selectionClick();
        onChanged(selected.first);
      },
      showSelectedIcon: false,
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        ),
      ),
    ),
    );
  }
}
