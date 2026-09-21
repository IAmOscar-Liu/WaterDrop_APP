import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/constants/colors.dart';

typedef DetailsSheetBuilder =
    Widget Function(BuildContext context, ScrollController scrollController);

/// Opens a half-height detail sheet that can expand below the top app bar.
/// Attach the supplied controller to the content's primary scrollable.
Future<T?> showDraggableDetailsSheet<T>({
  required BuildContext context,
  required WidgetBuilder headerBuilder,
  required DetailsSheetBuilder bodyBuilder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.primaryColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => _DraggableDetailsSheet(
      headerBuilder: headerBuilder,
      bodyBuilder: bodyBuilder,
    ),
  );
}

class _DraggableDetailsSheet extends StatefulWidget {
  const _DraggableDetailsSheet({
    required this.headerBuilder,
    required this.bodyBuilder,
  });

  final WidgetBuilder headerBuilder;
  final DetailsSheetBuilder bodyBuilder;

  @override
  State<_DraggableDetailsSheet> createState() => _DraggableDetailsSheetState();
}

class _DraggableDetailsSheetState extends State<_DraggableDetailsSheet> {
  double _sheetSize = 0.5;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final maxChildSize =
        (mediaQuery.size.height - mediaQuery.padding.top - kToolbarHeight) /
        mediaQuery.size.height;

    return NotificationListener<DraggableScrollableNotification>(
      onNotification: (notification) {
        if (notification.depth == 0 &&
            (notification.extent - _sheetSize).abs() > 0.01) {
          setState(() => _sheetSize = notification.extent);
        }
        return false;
      },
      child: DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.5,
        maxChildSize: maxChildSize.clamp(0.5, 1.0).toDouble(),
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Icon(
                  _sheetSize <= 0.51
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: AppColors.secondaryTextColor,
                ),
              ),
              const SizedBox(height: 8),
              widget.headerBuilder(context),
              const SizedBox(height: 16),
              Expanded(child: widget.bodyBuilder(context, scrollController)),
            ],
          ),
        ),
      ),
    );
  }
}
