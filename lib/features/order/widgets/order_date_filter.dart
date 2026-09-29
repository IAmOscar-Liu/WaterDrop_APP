import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/features/order/order_date_range.dart';
import 'package:flutter_ad_ecommerce/features/order/widgets/order_date_range_dialog.dart';
import 'package:flutter_ad_ecommerce/shared/widgets/filter_button.dart';
import 'package:flutter_ad_ecommerce/utils/formatter.dart';

class OrderDateFilter extends StatefulWidget {
  const OrderDateFilter({
    super.key,
    required this.range,
    required this.onChanged,
  });

  final OrderDateRange? range;
  final ValueChanged<OrderDateRange?> onChanged;

  @override
  State<OrderDateFilter> createState() => _OrderDateFilterState();
}

class _OrderDateFilterState extends State<OrderDateFilter> {
  String? _presetLabel;

  String get _label {
    final range = widget.range;
    if (range == null) return '選擇日期區間';
    final value =
        _presetLabel ??
        '${range.start == null ? '無限制' : Formatter.formatDateOnly(range.start!)} ~ '
            '${range.end == null ? '無限制' : Formatter.formatDateOnly(range.end!)}';
    return '日期區間:$value';
  }

  void _selectRange(OrderDateRange? range, {String? presetLabel}) {
    setState(() => _presetLabel = presetLabel);
    widget.onChanged(range);
  }

  Future<void> _pickRange(BuildContext context) async {
    final selected = await showDialog<OrderDateRange>(
      context: context,
      builder: (_) => OrderDateRangeDialog(initialRange: widget.range),
    );
    if (!context.mounted || selected == null) return;
    _selectRange(selected);
  }

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      menuChildren: [
        MenuItemButton(
          onPressed: () => _selectRange(null),
          child: const Text('全部'),
        ),
        MenuItemButton(
          onPressed: () => _selectRange(
            recentWeekOrderRange(DateTime.now()),
            presetLabel: '最近一週',
          ),
          child: const Text('最近一週'),
        ),
        MenuItemButton(
          onPressed: () => _selectRange(
            recentMonthOrderRange(DateTime.now()),
            presetLabel: '最近一個月',
          ),
          child: const Text('最近一個月'),
        ),
        MenuItemButton(
          onPressed: () => _pickRange(context),
          child: const Text('自訂'),
        ),
      ],
      builder: (context, controller, child) => FilterButton(
        isSelected: widget.range != null,
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
        icon: const Icon(Icons.calendar_today, size: 18),
        child: Text(_label),
      ),
    );
  }
}
