import 'package:flutter/material.dart';

import '../../../../app/design_tokens.dart';
import '../../../../app/theme.dart';
import '../voice_copy.dart';

/// Modal overlay shown while waiting for ASR/NLP after user finished speaking.
/// Blocks body touches; AppBar (e.g. back) remains clickable.
/// Uses opacity + scale entry animation and layered shadow for enterprise-style UX.
class VoiceRecognitionLoading extends StatelessWidget {
  const VoiceRecognitionLoading({super.key});

  static const Duration _entryDuration = Duration(milliseconds: 280);
  static const double _dialogRadius = 24;

  /// Softer scrim than default; avoids heavy BackdropFilter for performance.
  static const Color _scrimColor = Color(0x33000000);

  /// Layered shadow for depth without heavy blur.
  static List<BoxShadow> _dialogShadow(ColorScheme scheme) => [
    BoxShadow(
      color: scheme.shadow.withValues(alpha: 0.05),
      offset: const Offset(0, 4),
      blurRadius: 12,
    ),
    BoxShadow(
      color: scheme.shadow.withValues(alpha: 0.1),
      offset: const Offset(0, 8),
      blurRadius: 24,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      label: VoiceCopy.recognizingHint,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: Container(
          color: _scrimColor,
          alignment: Alignment.center,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: _entryDuration,
            curve: Curves.fastOutSlowIn,
            builder: (context, double t, _) {
              final opacity = t.clamp(0.0, 1.0);
              final scale = 0.94 + 0.06 * t;
              return Opacity(
                opacity: opacity,
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xxl,
                      vertical: AppSpacing.xxl + AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(_dialogRadius),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.6),
                        width: 1,
                      ),
                      boxShadow: _dialogShadow(colorScheme),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        RepaintBoundary(
                          child: SizedBox(
                            width: 44,
                            height: 44,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              strokeCap: StrokeCap.round,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          VoiceCopy.recognizingHint,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Theme.of(context).colorScheme.onSurface,
                                letterSpacing: 0.2,
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
