import 'package:flutter/material.dart';

/// Threshold (logical px) beyond which pointer movement is treated as drag, not tap.
/// Aligned with Material tap slop to avoid click/drag conflicts.
const double kDraggableFabDragThreshold = 18.0;

/// Snap animation duration per spec.
const Duration kDraggableFabSnapDuration = Duration(milliseconds: 200);

/// Wraps a FAB group so it can be dragged as a single unit. Handles drag vs tap
/// via movement threshold, snap-to-edge on release, and delegates clamping to parent.
class DraggableFabGroup extends StatefulWidget {
  const DraggableFabGroup({
    super.key,
    required this.offset,
    required this.onOffsetChanged,
    this.snapLeftX,
    this.snapRightX,
    this.onSnapEnd,
    required this.child,
  });

  final Offset offset;
  final void Function(Offset) onOffsetChanged;

  /// Left edge X for snap (group origin). If null, snap is skipped.
  final double? snapLeftX;
  /// Right edge X for snap (group origin). If null, snap is skipped.
  final double? snapRightX;
  /// Called once when snap animation finishes with the final offset so parent can persist.
  final void Function(Offset)? onSnapEnd;

  final Widget child;

  @override
  State<DraggableFabGroup> createState() => _DraggableFabGroupState();
}

class _DraggableFabGroupState extends State<DraggableFabGroup>
    with SingleTickerProviderStateMixin {
  bool _isDragging = false;
  /// Pointer position at contact; used to detect threshold.
  Offset? _pointerDownPosition;
  /// Offset and pointer position at drag start; delta from here drives position.
  Offset _dragStartOffset = Offset.zero;
  Offset? _dragStartPointerPosition;
  late AnimationController _snapController;
  late Animation<Offset> _snapAnimation;

  @override
  void initState() {
    super.initState();
    _snapController = AnimationController(
      duration: kDraggableFabSnapDuration,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _snapController.dispose();
    super.dispose();
  }

  /// Cached for the current gesture to avoid tree walk on every move.
  RenderBox? _cachedOffsetSpaceBox;

  void _onPointerDown(PointerDownEvent event) {
    _isDragging = false;
    _pointerDownPosition = event.position;
    _cachedOffsetSpaceBox = context.findAncestorRenderObjectOfType<RenderBox>();
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_pointerDownPosition == null) return;
    final box = _cachedOffsetSpaceBox;
    final startPos = box != null
        ? box.globalToLocal(_pointerDownPosition!)
        : _pointerDownPosition!;
    final curPos =
        box != null ? box.globalToLocal(event.position) : event.position;
    final distance = (curPos - startPos).distance;
    if (!_isDragging) {
      if (distance > kDraggableFabDragThreshold) {
        _isDragging = true;
        _dragStartOffset = widget.offset;
        _dragStartPointerPosition = curPos;
        final newOffset =
            _dragStartOffset + (curPos - _dragStartPointerPosition!);
        widget.onOffsetChanged(newOffset);
      }
      return;
    }
    final newOffset =
        _dragStartOffset + (curPos - _dragStartPointerPosition!);
    widget.onOffsetChanged(newOffset);
  }

  void _onPointerUp(PointerUpEvent event) {
    if (!_isDragging) {
      _pointerDownPosition = null;
      _cachedOffsetSpaceBox = null;
      return;
    }
    _pointerDownPosition = null;
    _dragStartPointerPosition = null;
    _cachedOffsetSpaceBox = null;
    _isDragging = false;
    _startSnap(widget.offset);
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (_isDragging) {
      _isDragging = false;
      _startSnap(widget.offset);
    }
    _pointerDownPosition = null;
    _dragStartPointerPosition = null;
    _cachedOffsetSpaceBox = null;
  }

  void _startSnap(Offset current) {
    final leftX = widget.snapLeftX;
    final rightX = widget.snapRightX;
    if (leftX == null || rightX == null) {
      widget.onSnapEnd?.call(current);
      return;
    }
    final mid = (leftX + rightX) / 2;
    final targetX = current.dx <= mid ? leftX : rightX;
    final snapped = Offset(targetX, current.dy);

    _snapAnimation = Tween<Offset>(
      begin: current,
      end: snapped,
    ).animate(CurvedAnimation(
      parent: _snapController,
      curve: Curves.easeOut,
    ));

    void listener() {
      widget.onOffsetChanged(_snapAnimation.value);
    }

    _snapController
      ..removeListener(listener)
      ..addListener(listener)
      ..forward(from: 0).then((_) {
        _snapController.removeListener(listener);
        widget.onOffsetChanged(snapped);
        widget.onSnapEnd?.call(snapped);
      });
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Listener(
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerUp,
        onPointerCancel: _onPointerCancel,
        behavior: HitTestBehavior.translucent,
        child: widget.child,
      ),
    );
  }
}
