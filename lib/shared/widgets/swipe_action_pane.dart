import 'package:flutter/material.dart';

/// A horizontal reveal pane. Swiping never invokes an action by itself.
class SwipeActionPane extends StatefulWidget {
  const SwipeActionPane({
    super.key,
    required this.open,
    required this.enabled,
    required this.width,
    required this.onOpenChanged,
    required this.actions,
    required this.child,
  });
  final bool open;
  final bool enabled;
  final double width;
  final ValueChanged<bool> onOpenChanged;
  final List<Widget> actions;
  final Widget child;
  @override
  State<SwipeActionPane> createState() => _SwipeActionPaneState();
}

class _SwipeActionPaneState extends State<SwipeActionPane> {
  double get _actionWidth => widget.width;
  double? _dragOffset;
  @override
  Widget build(BuildContext context) {
    final offset = widget.enabled
        ? _dragOffset ?? (widget.open ? _actionWidth : 0.0)
        : 0.0;
    return GestureDetector(
      onHorizontalDragUpdate: !widget.enabled
          ? null
          : (details) {
              setState(() {
                final current =
                    _dragOffset ?? (widget.open ? _actionWidth : 0.0);
                _dragOffset = (current - details.delta.dx).clamp(
                  0.0,
                  _actionWidth,
                );
              });
            },
      onHorizontalDragEnd: !widget.enabled
          ? null
          : (details) {
              final velocity = details.primaryVelocity ?? 0;
              final current = _dragOffset ?? (widget.open ? _actionWidth : 0.0);
              widget.onOpenChanged(
                velocity.abs() > 300
                    ? velocity < 0
                    : current > _actionWidth / 2,
              );
              setState(() => _dragOffset = null);
            },
      onHorizontalDragCancel: () => setState(() => _dragOffset = null),
      child: ClipRect(
        child: Stack(
          children: [
            if (offset > 0)
              Positioned.fill(
                right: 8,
                top: 4,
                bottom: 4,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: _actionWidth,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: widget.actions,
                    ),
                  ),
                ),
              ),
            AnimatedContainer(
              duration: _dragOffset != null
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              transform: Matrix4.translationValues(-offset, 0, 0),
              child: widget.child,
            ),
          ],
        ),
      ),
    );
  }
}
