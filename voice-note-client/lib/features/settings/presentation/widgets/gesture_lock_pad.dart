import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme.dart';

const int _gridSize = 3;
const int _minPoints = 4;

/// Reusable 3x3 gesture lock pad. Unselected: 16dp stroke #E5E6EB;
/// selected: 20dp fill brand; lines 4dp 80% alpha; error state + shake.
class GestureLockPad extends StatefulWidget {
  const GestureLockPad({
    super.key,
    required this.path,
    required this.isError,
    required this.onPointTapped,
    required this.onPathComplete,
    this.onGestureStart,
    this.padSize = 280,
  });

  final List<int> path;
  final bool isError;
  final void Function(int index) onPointTapped;
  final void Function() onPathComplete;
  /// Called when user starts a new drag. [firstNode] is non-null if touch landed on a node;
  /// parent should set path to [firstNode] or [] so each gesture starts fresh.
  final void Function(int? firstNode)? onGestureStart;
  final double padSize;

  @override
  State<GestureLockPad> createState() => _GestureLockPadState();
}

class _GestureLockPadState extends State<GestureLockPad>
    with SingleTickerProviderStateMixin {
  int? _lastTappedIndex;
  late AnimationController _shakeController;
  final ValueNotifier<Offset?> _trailingNotifier = ValueNotifier<Offset?>(null);

  static const double _nodeSizeSelected = 20;
  static const double _lineWidth = 4;

  double _indexToX(int i) {
    final spacing = widget.padSize / (_gridSize + 1);
    final col = i % _gridSize;
    return spacing * (col + 1);
  }

  double _indexToY(int i) {
    final spacing = widget.padSize / (_gridSize + 1);
    final row = i ~/ _gridSize;
    return spacing * (row + 1);
  }

  bool _areNeighbors(int a, int b) {
    final ar = a ~/ _gridSize, ac = a % _gridSize;
    final br = b ~/ _gridSize, bc = b % _gridSize;
    return (ar - br).abs() <= 1 && (ac - bc).abs() <= 1;
  }

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _trailingNotifier.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(GestureLockPad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isError && !oldWidget.isError) {
      _shakeController.forward(from: 0);
    }
  }

  int? _nodeAt(Offset localPosition, [double? radius]) {
    final hitRadius = radius ?? _nodeSizeSelected;
    for (var i = 0; i < _gridSize * _gridSize; i++) {
      final cx = _indexToX(i);
      final cy = _indexToY(i);
      final dx = localPosition.dx - cx;
      final dy = localPosition.dy - cy;
      if (dx * dx + dy * dy <= hitRadius * hitRadius) return i;
    }
    return null;
  }

  /// Larger radius for pan start so edge touches still register as first point.
  static const double _panStartHitRadius = 28;

  void _onPanStart(DragStartDetails details) {
    _trailingNotifier.value = details.localPosition;
    final nodeAt = _nodeAt(details.localPosition, _panStartHitRadius);
    _lastTappedIndex = nodeAt;
    if (widget.onGestureStart != null) {
      widget.onGestureStart!(nodeAt);
    } else if (nodeAt != null && !widget.path.contains(nodeAt)) {
      widget.onPointTapped(nodeAt);
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    _trailingNotifier.value = details.localPosition;
    const hitRadius = _nodeSizeSelected;
    for (var i = 0; i < _gridSize * _gridSize; i++) {
      final cx = _indexToX(i);
      final cy = _indexToY(i);
      final dx = details.localPosition.dx - cx;
      final dy = details.localPosition.dy - cy;
      if (dx * dx + dy * dy <= hitRadius * hitRadius &&
          !widget.path.contains(i) &&
          (_lastTappedIndex == null ||
              _lastTappedIndex == i ||
              _areNeighbors(_lastTappedIndex!, i))) {
        _lastTappedIndex = i;
        widget.onPointTapped(i);
        return;
      }
      if (dx * dx + dy * dy <= hitRadius * hitRadius &&
          (widget.path.contains(i) ||
              (_lastTappedIndex != null && !_areNeighbors(_lastTappedIndex!, i)))) {
        return;
      }
    }
  }

  void _onPanEnd(DragEndDetails _) {
    _trailingNotifier.value = null;
    _lastTappedIndex = null;
    if (widget.path.length >= _minPoints) widget.onPathComplete();
  }

  @override
  Widget build(BuildContext context) {
    final lineColor = widget.isError
        ? AppColors.expense.withValues(alpha: 0.8)
        : AppColors.brandPrimary.withValues(alpha: 0.8);
    final nodeColor = widget.isError ? AppColors.expense : AppColors.brandPrimary;

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _shakeController,
        builder: (context, child) {
          final shake = widget.isError
              ? 4.0 * math.sin(_shakeController.value * 2 * math.pi)
              : 0.0;
          return Transform.translate(
            offset: Offset(shake, 0),
            child: child,
          );
        },
        child: GestureDetector(
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          child: SizedBox(
            width: widget.padSize,
            height: widget.padSize,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ListenableBuilder(
                    listenable: _trailingNotifier,
                    builder: (context, _) => CustomPaint(
                      painter: _GestureLockPadPainter(
                        path: widget.path,
                        trailingOffset: _trailingNotifier.value,
                        indexToX: _indexToX,
                        indexToY: _indexToY,
                        color: lineColor,
                        lineWidth: _lineWidth,
                      ),
                    ),
                  ),
                ),
                ...List.generate(_gridSize * _gridSize, (i) {
                  final x = _indexToX(i);
                  final y = _indexToY(i);
                  final selected = widget.path.contains(i);
                  const halfTotal = 12.0; // _nodeSizeSelected/2 + _strokeWidth
                  return Positioned(
                    left: x - halfTotal,
                    top: y - halfTotal,
                    child: _GestureNode(
                      selected: selected,
                      nodeColor: nodeColor,
                      onTap: () {
                        widget.onPointTapped(i);
                        if (widget.path.length + 1 >= _minPoints) {
                          widget.onPathComplete();
                        }
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GestureNode extends StatelessWidget {
  const _GestureNode({
    required this.selected,
    required this.nodeColor,
    required this.onTap,
  });

  final bool selected;
  final Color nodeColor;
  final VoidCallback onTap;

  static const double _sizeUnselected = 16;
  static const double _sizeSelected = 20;
  static const double _strokeWidth = 2;

  @override
  Widget build(BuildContext context) {
    const totalSize = _sizeSelected + _strokeWidth * 2;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: totalSize,
          height: totalSize,
          child: Center(
            child: selected
                ? TweenAnimationBuilder<double>(
                    key: const ValueKey(true),
                    tween: Tween(begin: 0.8, end: 1.0),
                    duration: const Duration(milliseconds: 100),
                    builder: (context, scale, child) =>
                        Transform.scale(scale: scale, child: child!),
                    child: Container(
                      width: _sizeSelected,
                      height: _sizeSelected,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: nodeColor,
                      ),
                    ),
                  )
                : Container(
                    width: _sizeUnselected,
                    height: _sizeUnselected,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.transparent,
                      border: Border.all(
                        color: AppColors.gestureNodeStroke,
                        width: _strokeWidth,
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _GestureLockPadPainter extends CustomPainter {
  _GestureLockPadPainter({
    required this.path,
    required this.trailingOffset,
    required this.indexToX,
    required this.indexToY,
    required this.color,
    required this.lineWidth,
  }) : _paint = Paint()
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;

  final List<int> path;
  final Offset? trailingOffset;
  final double Function(int) indexToX;
  final double Function(int) indexToY;
  final Color color;
  final double lineWidth;
  final Paint _paint;

  @override
  void paint(Canvas canvas, Size size) {
    _paint
      ..color = color
      ..strokeWidth = lineWidth;
    for (var i = 0; i < path.length - 1; i++) {
      final a = path[i];
      final b = path[i + 1];
      canvas.drawLine(
        Offset(indexToX(a), indexToY(a)),
        Offset(indexToX(b), indexToY(b)),
        _paint,
      );
    }
    if (path.isNotEmpty && trailingOffset != null) {
      canvas.drawLine(
        Offset(indexToX(path.last), indexToY(path.last)),
        trailingOffset!,
        _paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GestureLockPadPainter old) =>
      old.path != path ||
      old.color != color ||
      old.trailingOffset != trailingOffset;
}
