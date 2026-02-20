import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/design_tokens.dart';
import 'fab_visibility_provider.dart';

/// Small toggle button for controlling exit FAB visibility in voice recording screen.
/// 
/// Positioned near the exit FAB, allows users to show/hide the exit FAB.
class VoiceExitFabToggleButton extends ConsumerWidget {
  const VoiceExitFabToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fabVisible = ref.watch(voiceExitFabVisibilityProvider);
    final theme = Theme.of(context);

    return SizedBox(
      width: 40,
      height: 40,
      child: FloatingActionButton(
        heroTag: 'voice_exit_fab_toggle',
        onPressed: () {
          HapticFeedback.lightImpact();
          ref.read(voiceExitFabVisibilityProvider.notifier).state = !fabVisible;
        },
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 4,
        mini: true,
        child: Icon(
          fabVisible ? Icons.visibility_off : Icons.visibility,
          size: AppIconSize.md,
        ),
      ),
    );
  }
}
