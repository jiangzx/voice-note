import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/design_tokens.dart';
import '../../../../app/theme.dart';
import '../../domain/voice_state.dart';

/// Central animated widget reflecting the current voice state.
///
/// - [idle]: Static mic icon
/// - [listening]: Slow pulsing circle (breathing animation)
/// - [recognizing]: Expanding ring waves
/// - [confirming]: Checkmark with gentle pulse
class VoiceAnimationWidget extends StatefulWidget {
  final VoiceState state;
  final double size;

  const VoiceAnimationWidget({
    super.key,
    required this.state,
    this.size = 120,
  });

  @override
  State<VoiceAnimationWidget> createState() => _VoiceAnimationWidgetState();
}

class _VoiceAnimationWidgetState extends State<VoiceAnimationWidget>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _syncAnimations();
  }

  @override
  void didUpdateWidget(VoiceAnimationWidget old) {
    super.didUpdateWidget(old);
    if (old.state != widget.state) _syncAnimations();
  }

  void _syncAnimations() {
    _pulseController.stop();
    _waveController.stop();

    switch (widget.state) {
      case VoiceState.idle:
        break;
      case VoiceState.listening:
        _pulseController.repeat(reverse: true);
        break;
      case VoiceState.recognizing:
        _waveController.repeat();
        break;
      case VoiceState.confirming:
        _pulseController.repeat(reverse: true);
        break;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stateLabel = switch (widget.state) {
      VoiceState.idle => '等待中',
      VoiceState.listening => '正在聆听',
      VoiceState.recognizing => '正在识别语音',
      VoiceState.confirming => '识别完成，请确认',
    };

    return Semantics(
      label: stateLabel,
      liveRegion: true,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedSwitcher(
          duration: AppDuration.normal,
          child: switch (widget.state) {
            VoiceState.idle => _buildIdle(),
            VoiceState.listening => _buildListening(),
            VoiceState.recognizing => _buildRecognizing(),
            VoiceState.confirming => _buildConfirming(),
          },
        ),
      ),
    );
  }

  Widget _buildIdle() {
    return _CircleIcon(
      key: const ValueKey('idle'),
      color: AppColors.backgroundTertiary,
      iconColor: AppColors.textSecondary,
      icon: Icons.mic_none_rounded,
      size: widget.size * 0.6,
    );
  }

  Widget _buildListening() {
    final baseColor = AppColors.brandPrimary.withValues(alpha: 0.15);
    return AnimatedBuilder(
      key: const ValueKey('listening'),
      animation: _pulseController,
      builder: (context, child) {
        final scale = 1.0 + _pulseController.value * 0.15;
        final opacity = 0.6 + _pulseController.value * 0.4;
        return Transform.scale(
          scale: scale,
          child: _CircleIcon(
            color: baseColor,
            iconColor: AppColors.brandPrimary.withValues(alpha: opacity),
            icon: Icons.mic_rounded,
            size: widget.size * 0.6,
          ),
        );
      },
    );
  }

  Widget _buildRecognizing() {
    return AnimatedBuilder(
      key: const ValueKey('recognizing'),
      animation: _waveController,
      builder: (context, _) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _WaveRingPainter(
            progress: _waveController.value,
            color: AppColors.brandPrimary,
          ),
          child: Center(
            child: _CircleIcon(
              color: AppColors.brandPrimary.withValues(alpha: 0.2),
              iconColor: AppColors.brandPrimary,
              icon: Icons.mic_rounded,
              size: widget.size * 0.45,
            ),
          ),
        );
      },
    );
  }

  Widget _buildConfirming() {
    return AnimatedBuilder(
      key: const ValueKey('confirming'),
      animation: _pulseController,
      builder: (context, _) {
        final scale = 1.0 + _pulseController.value * 0.08;
        return Transform.scale(
          scale: scale,
          child: _CircleIcon(
            color: AppColors.brandPrimary.withValues(alpha: 0.12),
            iconColor: AppColors.brandPrimary,
            icon: Icons.check_rounded,
            size: widget.size * 0.6,
          ),
        );
      },
    );
  }
}

/// A simple circle with an icon centered inside.
class _CircleIcon extends StatelessWidget {
  final Color color;
  final Color iconColor;
  final IconData icon;
  final double size;

  const _CircleIcon({
    super.key,
    required this.color,
    required this.iconColor,
    required this.icon,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      child: Icon(icon, color: iconColor, size: size * 0.45),
    );
  }
}

/// Paints expanding concentric ring waves.
class _WaveRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  static const int _ringCount = 3;

  _WaveRingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.min(size.width, size.height) / 2;

    for (int i = 0; i < _ringCount; i++) {
      final phase = (progress + i / _ringCount) % 1.0;
      final radius = maxRadius * 0.4 + maxRadius * 0.6 * phase;
      final opacity = (1.0 - phase).clamp(0.0, 0.5);

      final paint = Paint()
        ..color = color.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_WaveRingPainter old) =>
      old.progress != progress || old.color != color;
}

/// Animated voice bars for "speaking" state (e.g. push-to-talk active).
/// Uses CustomPaint to avoid per-frame layout (only repaint).
class SpeakingWaveform extends StatefulWidget {
  final double size;
  final Color color;

  const SpeakingWaveform({
    super.key,
    this.size = 64,
    this.color = Colors.white,
  });

  @override
  State<SpeakingWaveform> createState() => _SpeakingWaveformState();
}

class _SpeakingWaveformState extends State<SpeakingWaveform>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            size: Size(widget.size, widget.size),
            painter: _VoiceBarsPainter(
              progress: _controller.value,
              color: widget.color,
              size: widget.size,
            ),
          );
        },
      ),
    );
  }
}

class _VoiceBarsPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double size;

  static const int _barCount = 5;
  static const double _barWidth = 5.0;
  static const double _gap = 4.0;

  _VoiceBarsPainter({
    required this.progress,
    required this.color,
    required this.size,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final maxBarHeight = this.size * 0.4;
    final minBarHeight = this.size * 0.12;
    const totalWidth = _barCount * _barWidth + (_barCount - 1) * _gap;
    final left = (this.size - totalWidth) / 2;
    final centerY = this.size / 2;

    final paint = Paint()..color = color;

    for (int i = 0; i < _barCount; i++) {
      final phase = (i / _barCount) * 2 * math.pi;
      final t = progress * 2 * math.pi + phase;
      final normalized = (math.sin(t) + 1) / 2;
      final barHeight =
          minBarHeight + normalized * (maxBarHeight - minBarHeight);
      final x = left + i * (_barWidth + _gap) + _barWidth / 2;
      final top = centerY - barHeight / 2;
      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x - _barWidth / 2, top, _barWidth, barHeight),
        const Radius.circular(_barWidth / 2),
      );
      canvas.drawRRect(rrect, paint);
    }
  }

  @override
  bool shouldRepaint(_VoiceBarsPainter old) =>
      old.progress != progress || old.color != color || old.size != size;
}
