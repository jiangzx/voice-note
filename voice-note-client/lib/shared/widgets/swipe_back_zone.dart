import 'package:flutter/material.dart';

/// Left-edge zone: swipe right triggers [onBack]. Use to add gesture back on pages
/// that don't use CupertinoPage (e.g. shell routes).
class SwipeBackZone extends StatefulWidget {
  const SwipeBackZone({super.key, required this.onBack, required this.child});

  final VoidCallback onBack;
  final Widget child;

  static const double edgeWidth = 24;

  @override
  State<SwipeBackZone> createState() => _SwipeBackZoneState();
}

class _SwipeBackZoneState extends State<SwipeBackZone> {
  double _dragDx = 0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: SwipeBackZone.edgeWidth,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragUpdate: (DragUpdateDetails details) {
              _dragDx += details.delta.dx;
              if (_dragDx > 20) {
                widget.onBack();
                _dragDx = double.negativeInfinity;
              }
            },
            onHorizontalDragEnd: (_) => setState(() => _dragDx = 0),
            onHorizontalDragCancel: () => setState(() => _dragDx = 0),
          ),
        ),
      ],
    );
  }
}
