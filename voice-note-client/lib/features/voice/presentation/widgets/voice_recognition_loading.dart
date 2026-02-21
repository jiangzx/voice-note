import 'package:flutter/material.dart';

import '../../../../app/design_tokens.dart';
import '../../../../app/theme.dart';
import '../voice_copy.dart';

/// Modal overlay shown while waiting for ASR/NLP after user finished speaking.
/// Blocks body touches; AppBar (e.g. back) remains clickable.
class VoiceRecognitionLoading extends StatelessWidget {
  const VoiceRecognitionLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: VoiceCopy.recognizingHint,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {}, // Consume taps; do not close.
        child: Container(
          color: const Color(0x4D000000),
          alignment: Alignment.center,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
            padding: const EdgeInsets.all(AppSpacing.xxl),
            decoration: const BoxDecoration(
              color: AppColors.backgroundPrimary,
              borderRadius: AppRadius.cardAll,
              boxShadow: AppShadow.card,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.brandPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  VoiceCopy.recognizingHint,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontSize: 16,
                        color: AppColors.textPrimary,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
