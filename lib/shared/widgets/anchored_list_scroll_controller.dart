import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Applies a pending anchor while RenderViewport can still repeat layout in the
/// same frame. A post-frame jump paints the wrong row position for one frame.
class AnchoredListScrollController extends ScrollController {
  // Keep the same visible row at the same screen position when live updates
  // reorder rows. Correct during layout, before the changed rows are painted.
  void preserveItems(
    Iterable<String> ids,
    Map<String, GlobalKey> keys,
    GlobalKey viewportKey,
  ) {
    if (!hasClients) return;
    final position = this.position as _AnchoredListScrollPosition;
    if (position.isScrollingNotifier.value) return;
    final atTop = position.pixels <= position.minScrollExtent + 1;
    final viewport = viewportKey.currentContext?.findRenderObject();
    GlobalKey? anchor;
    double? previousY;
    if (!atTop && viewport is RenderBox && viewport.hasSize) {
      const top = 0.0;
      final bottom = viewport.size.height;
      for (final id in ids) {
        final key = keys[id];
        final box = key?.currentContext?.findRenderObject();
        if (box is! RenderBox || !box.hasSize) continue;
        final y = box
            .localToGlobal(
              Offset.zero,
              ancestor: RenderAbstractViewport.of(box),
            )
            .dy;
        if (y + box.size.height > top &&
            y < bottom &&
            (previousY == null || y < previousY)) {
          anchor = key;
          previousY = y;
        }
      }
    }
    position.preserveOffset(() {
      if (atTop) return position.minScrollExtent;
      final box = anchor?.currentContext?.findRenderObject();
      if (box is RenderBox && box.hasSize && previousY != null) {
        return position.pixels +
            box
                .localToGlobal(
                  Offset.zero,
                  ancestor: RenderAbstractViewport.of(box),
                )
                .dy -
            previousY;
      }
      return null;
    });
  }

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) => _AnchoredListScrollPosition(
    physics: physics,
    context: context,
    oldPosition: oldPosition,
  );
}

class _AnchoredListScrollPosition extends ScrollPositionWithSingleContext {
  _AnchoredListScrollPosition({
    required super.physics,
    required super.context,
    super.oldPosition,
  });

  double? Function()? _pendingOffset;

  void preserveOffset(double? Function() offset) {
    _pendingOffset = offset;
    // If this rebuild did not need layout, do not retain an anchor that could
    // interfere with a later user gesture or unrelated viewport resize.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (identical(_pendingOffset, offset)) _pendingOffset = null;
    });
  }

  @override
  void correctBy(double correction) {
    // Offscreen rows can change height before the sliver measures them. When
    // returning to the top, that estimate correction must not scroll us down.
    if (hasContentDimensions &&
        pixels == minScrollExtent &&
        correction > 0 &&
        _pendingOffset == null &&
        !isScrollingNotifier.value) {
      preserveOffset(() => minScrollExtent);
    }
    super.correctBy(correction);
  }

  @override
  bool applyContentDimensions(double minScrollExtent, double maxScrollExtent) {
    final pending = _pendingOffset;
    // Keep the anchor for every layout pass in this frame: moving keyed rows
    // of different heights can make the sliver request another correction.
    if (pending != null && !isScrollingNotifier.value) {
      final target = pending()?.clamp(minScrollExtent, maxScrollExtent);
      if (target != null && (target - pixels).abs() > 0.5) {
        correctPixels(target);
        return false;
      }
    }
    return super.applyContentDimensions(minScrollExtent, maxScrollExtent);
  }
}
