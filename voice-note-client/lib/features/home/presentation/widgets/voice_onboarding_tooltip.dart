import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/design_tokens.dart';
import '../../../../core/di/network_providers.dart';

const _keyVoiceOnboardingShown = 'voice_onboarding_shown';

/// Provider to check if voice onboarding has been shown.
final voiceOnboardingShownProvider = Provider<bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs.getBool(_keyVoiceOnboardingShown) ?? false;
});

/// Provider to mark voice onboarding as shown.
final markVoiceOnboardingShownProvider = Provider<Future<void> Function()>(
  (ref) => () async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(_keyVoiceOnboardingShown, true);
    ref.invalidate(voiceOnboardingShownProvider);
  },
);

/// Lightweight onboarding tooltip for voice feature.
///
/// Shows a brief hint pointing to the voice FAB on first visit.
/// Automatically dismisses after 3 seconds or can be manually closed.
class VoiceOnboardingTooltip extends ConsumerStatefulWidget {
  const VoiceOnboardingTooltip({super.key});

  @override
  ConsumerState<VoiceOnboardingTooltip> createState() =>
      _VoiceOnboardingTooltipState();
}

class _VoiceOnboardingTooltipState
    extends ConsumerState<VoiceOnboardingTooltip> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    final shown = ref.watch(voiceOnboardingShownProvider);

    if (shown || _dismissed) {
      return const SizedBox.shrink();
    }

    // Show tooltip after a brief delay to ensure UI is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && !_dismissed) {
          _showTooltip(context);
        }
      });
    });

    return const SizedBox.shrink();
  }

  void _showTooltip(BuildContext context) {
    final theme = Theme.of(context);
    final overlay = Overlay.of(context);
    OverlayEntry? overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 100,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 200),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: AppRadius.mdAll,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.arrow_downward,
                      size: AppIconSize.sm,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        '点击下方麦克风按钮开始语音记账',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: AppIconSize.sm),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        _dismissTooltip(overlayEntry);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);

    // Auto-dismiss after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && overlayEntry != null) {
        _dismissTooltip(overlayEntry);
      }
    });
  }

  void _dismissTooltip(OverlayEntry? entry) {
    if (!mounted || entry == null) return;

    setState(() {
      _dismissed = true;
    });

    entry.remove();

    // Mark as shown
    final markShown = ref.read<Future<void> Function()>(markVoiceOnboardingShownProvider);
    markShown();
  }
}
