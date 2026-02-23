import 'package:flutter/material.dart';

import '../../app/design_tokens.dart';
import '../../app/theme.dart';

/// Full-screen overlay shown once at app start: displays assets/splash/logo.png (mark + "AI 懂你说的，记账更轻松").
/// Hides after [duration] then fades out.
class SplashOverlay extends StatefulWidget {
  const SplashOverlay({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 800),
  });

  final Widget child;
  final Duration duration;

  @override
  State<SplashOverlay> createState() => _SplashOverlayState();
}

class _SplashOverlayState extends State<SplashOverlay>
    with SingleTickerProviderStateMixin {
  bool _visible = true;
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppDuration.normal,
    );
    _opacity = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    Future.delayed(widget.duration, () {
      if (!mounted) return;
      _controller.forward();
      Future.delayed(AppDuration.normal, () {
        if (!mounted) return;
        setState(() => _visible = false);
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_visible)
          AnimatedBuilder(
            animation: _opacity,
            builder: (context, _) {
              return IgnorePointer(
                child: Container(
                  color: AppColors.backgroundPrimary,
                  child: Opacity(
                    opacity: _opacity.value,
                    child: Center(
                      child: Image.asset(
                        'assets/splash/logo.png',
                        width: 270,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
