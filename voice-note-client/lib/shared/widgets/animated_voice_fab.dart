import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Floating action button for voice recording with pulsing animation.
class AnimatedVoiceFab extends StatefulWidget {
  const AnimatedVoiceFab({super.key});

  @override
  State<AnimatedVoiceFab> createState() => _AnimatedVoiceFabState();
}

class _AnimatedVoiceFabState extends State<AnimatedVoiceFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value,
            child: FloatingActionButton(
              heroTag: 'voice_fab',
              onPressed: () => context.push('/voice-recording'),
              backgroundColor: colorScheme.tertiaryContainer,
              child: Icon(
                Icons.mic_rounded,
                color: colorScheme.onTertiaryContainer,
              ),
            ),
          );
        },
      ),
    );
  }
}
