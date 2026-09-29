import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/constants/colors.dart';
import 'package:flutter_ad_ecommerce/features/order/order_date_range.dart';
import 'package:flutter_ad_ecommerce/utils/formatter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';

class OrderDateRangeDialog extends StatefulWidget {
  const OrderDateRangeDialog({super.key, this.initialRange});

  final OrderDateRange? initialRange;

  @override
  State<OrderDateRangeDialog> createState() => _OrderDateRangeDialogState();
}

class _OrderDateRangeDialogState extends State<OrderDateRangeDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _startController;
  late final TextEditingController _endController;

  @override
  void initState() {
    super.initState();
    final range = widget.initialRange;
    _startController = TextEditingController(
      text: range?.start == null ? '' : Formatter.formatDateOnly(range!.start!),
    );
    _endController = TextEditingController(
      text: range?.end == null ? '' : Formatter.formatDateOnly(range!.end!),
    );
    _startController.addListener(_onDatesChanged);
    _endController.addListener(_onDatesChanged);
  }

  void _onDatesChanged() => setState(() {});

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  DateTime? _parseDate(String text) {
    final value = text.trim();
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return null;
    try {
      final date = DateFormat('yyyy-MM-dd').parseStrict(value);
      return date.year >= 1 && date.year <= 9998 ? date : null;
    } on FormatException {
      return null;
    }
  }

  Future<void> _pickDate(TextEditingController controller) async {
    FocusScope.of(context).unfocus();
    final selected = await showDatePicker(
      context: context,
      initialDate: _parseDate(controller.text) ?? DateTime.now(),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      firstDate: DateTime(1),
      lastDate: DateTime(9998, 12, 31),
      confirmText: '確定',
      cancelText: '取消',
      builder: (context, child) => Localizations.override(
        context: context,
        locale: const Locale('zh', 'TW'),
        delegates: GlobalMaterialLocalizations.delegates,
        child: child!,
      ),
    );
    if (!mounted || selected == null) return;
    controller.text = Formatter.formatDateOnly(selected);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      OrderDateRange(
        start: _parseDate(_startController.text),
        end: _parseDate(_endController.text),
      ),
    );
  }

  Widget _dateField(TextEditingController controller, {required bool isStart}) {
    final label = isStart ? '開始日期' : '結束日期';
    return TextFormField(
      controller: controller,
      readOnly: true,
      onTap: () => _pickDate(controller),
      decoration: InputDecoration(
        labelText: label,
        hintText: 'YYYY-MM-DD',
        prefixIcon: IconButton(
          tooltip: '選擇$label',
          onPressed: () => _pickDate(controller),
          icon: const Icon(Icons.calendar_today, size: 20),
        ),
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                tooltip: '清除$label',
                onPressed: controller.clear,
                icon: const Icon(Icons.clear, size: 20),
              )
            : null,
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) return null;
        final date = _parseDate(value);
        if (date == null) return '請輸入有效日期（YYYY-MM-DD）';
        final start = _parseDate(_startController.text);
        if (!isStart && start != null && date.isBefore(start)) {
          return '結束日期不可早於開始日期';
        }
        return null;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: AlertDialog(
        title: const Text('選擇日期區間'),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dateField(_startController, isStart: true),
                const SizedBox(height: 16),
                _dateField(_endController, isStart: false),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.navbarIndicatorColor,
              foregroundColor: AppColors.primaryTextColor,
            ),
            onPressed:
                _startController.text.trim().isNotEmpty ||
                    _endController.text.trim().isNotEmpty
                ? _submit
                : null,
            child: const Text('確定'),
          ),
        ],
      ),
    );
  }
}
