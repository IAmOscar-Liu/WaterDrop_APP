import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ad_ecommerce/constants/colors.dart';
import 'package:flutter_ad_ecommerce/features/order/widgets/order_detail_rows.dart';
import 'package:flutter_ad_ecommerce/features/order/widgets/order_status_badge.dart';
import 'package:flutter_ad_ecommerce/models/order.dart';
import 'package:flutter_ad_ecommerce/provider/order_provider.dart';
import 'package:flutter_ad_ecommerce/utils/formatter.dart';
import 'package:flutter_ad_ecommerce/utils/number_formatter_extension.dart';
import 'package:flutter_ad_ecommerce/utils/parse_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<bool> showCreateRefundDialog(
  BuildContext context, {
  required OrderItem item,
}) async {
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _CreateRefundDialog(item: item),
      ) ??
      false;
}

void showRefundItemsBottomSheet(
  BuildContext context, {
  required OrderItem item,
  required Future<bool> Function(OrderItem item) onCreateRefund,
}) {
  final refundItems = item.refundItems;
  final canCreateRefund = item.canRefund && item.remainingRefundQuantity > 0;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.primaryColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      final mediaQuery = MediaQuery.of(context);
      final maxChildSize =
          (mediaQuery.size.height - mediaQuery.padding.top - kToolbarHeight) /
          mediaQuery.size.height;
      var sheetSize = 0.5;

      return StatefulBuilder(
        builder: (context, setSheetState) {
          return NotificationListener<DraggableScrollableNotification>(
            onNotification: (notification) {
              if ((notification.extent - sheetSize).abs() > 0.01) {
                setSheetState(() {
                  sheetSize = notification.extent;
                });
              }
              return false;
            },
            child: DraggableScrollableSheet(
              initialChildSize: 0.5,
              minChildSize: 0.5,
              maxChildSize: maxChildSize.clamp(0.5, 1.0).toDouble(),
              expand: false,
              builder: (context, scrollController) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Icon(
                          sheetSize <= 0.51
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          color: AppColors.secondaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              '退貨詳情',
                              style: TextStyle(
                                color: AppColors.primaryTextColor,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (canCreateRefund)
                            FilledButton(
                              onPressed: () async {
                                final created = await onCreateRefund(item);
                                if (created && context.mounted) {
                                  Navigator.of(context).pop();
                                }
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primaryButtonColor,
                                foregroundColor: AppColors.primaryTextColor,
                                padding: EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: StadiumBorder(),
                                textStyle: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.add, size: 16),
                                  SizedBox(width: 2),
                                  Text('新增'),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: refundItems.length,
                          itemBuilder: (context, index) {
                            return _RefundItemCard(
                              refundItem: refundItems[index],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      );
    },
  );
}

class _RefundItemCard extends StatelessWidget {
  final RefundItem refundItem;

  const _RefundItemCard({required this.refundItem});

  String _refundCoinsText() {
    final coins = refundItem.coins;
    final returnableCoins = refundItem.returnableCoins;

    if (returnableCoins != null && returnableCoins != coins) {
      return '${returnableCoins.formatWithCommas()} (${(coins - returnableCoins).formatWithCommas()} 已逾期，無法退還)';
    }
    return coins.formatWithCommas();
  }

  @override
  Widget build(BuildContext context) {
    final reason = refundItem.reason?.trim();
    final note = refundItem.note?.trim();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: AppColors.tileColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  '申請時間:',
                  style: TextStyle(
                    color: AppColors.secondaryTextColor,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    Formatter.formatDateTime(refundItem.createdAt),
                    style: const TextStyle(
                      color: AppColors.primaryTextColor,
                      fontSize: 14,
                    ),
                  ),
                ),
                RefundStatusBadge(status: refundItem.status),
              ],
            ),
          ),
          OrderDetailRow(label: '退貨數量:', value: refundItem.quantity.toString()),
          OrderDetailRow(
            label: '退款金額:',
            value: (refundItem.paidRefundAmount + refundItem.extraRefundAmount)
                .toDollarsString(prefix: "NT"),
          ),
          OrderDetailRow(label: '退還金幣:', value: _refundCoinsText()),
          if (reason?.isNotEmpty == true)
            OrderDetailRow(label: '退貨原因:', value: reason!),
          if (note?.isNotEmpty == true)
            OrderDetailRow(label: '備註:', value: note!),
          OrderDetailRow(
            label: '最後更新時間:',
            value: Formatter.formatDateTime(refundItem.updatedAt),
          ),
        ],
      ),
    );
  }
}

class _CreateRefundDialog extends ConsumerStatefulWidget {
  const _CreateRefundDialog({required this.item});

  final OrderItem item;

  @override
  ConsumerState<_CreateRefundDialog> createState() =>
      _CreateRefundDialogState();
}

class _CreateRefundDialogState extends ConsumerState<_CreateRefundDialog> {
  late final TextEditingController _quantityController;
  late final TextEditingController _reasonController;
  late final TextEditingController _noteController;

  bool _isSubmitting = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController(text: '1');
    _reasonController = TextEditingController();
    _noteController = TextEditingController();
    _quantityController.addListener(_handleFormChanged);
    _reasonController.addListener(_handleFormChanged);
  }

  @override
  void dispose() {
    _quantityController.removeListener(_handleFormChanged);
    _reasonController.removeListener(_handleFormChanged);
    _quantityController.dispose();
    _reasonController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _handleFormChanged() {
    setState(() {
      if (_errorText != null) _errorText = null;
    });
  }

  bool get _isFormValid {
    final quantity = ParseUtils.parseInt(_quantityController.text.trim()) ?? 0;
    final reason = _reasonController.text.trim();
    return quantity >= 1 &&
        quantity <= widget.item.remainingRefundQuantity &&
        reason.isNotEmpty &&
        widget.item.product?.sellerId.isNotEmpty == true;
  }

  InputDecoration _inputDecoration({
    required String labelText,
    String? helperText,
    bool alignLabelWithHint = false,
  }) {
    const border = OutlineInputBorder(
      borderSide: BorderSide(color: AppColors.borderColor),
    );

    return InputDecoration(
      labelText: labelText,
      helperText: helperText,
      alignLabelWithHint: alignLabelWithHint,
      labelStyle: const TextStyle(color: AppColors.secondaryTextColor),
      floatingLabelStyle: const TextStyle(color: AppColors.infoColor),
      helperStyle: const TextStyle(color: AppColors.secondaryTextColor),
      filled: true,
      fillColor: AppColors.fieldInputColor,
      enabledBorder: border,
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: AppColors.infoColor),
      ),
      disabledBorder: border,
    );
  }

  Future<void> _submit() async {
    final item = widget.item;
    final maxQuantity = item.remainingRefundQuantity;
    final quantity = ParseUtils.parseInt(_quantityController.text.trim()) ?? 0;
    final reason = _reasonController.text.trim();
    final note = _noteController.text.trim();
    final accountId = item.product?.sellerId;

    if (quantity < 1 || quantity > maxQuantity) {
      setState(() {
        _errorText = '退貨數量需介於 1 到 $maxQuantity';
      });
      return;
    }
    if (reason.isEmpty) {
      setState(() {
        _errorText = '請填寫退貨原因';
      });
      return;
    }
    if (accountId == null || accountId.isEmpty) {
      setState(() {
        _errorText = '找不到賣家資訊，無法申請退貨';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    final result = await ref
        .read(orderNotifierProvider.notifier)
        .createRefund(
          orderItemId: item.id,
          accountId: accountId,
          quantity: quantity,
          reason: reason,
          note: note.isEmpty ? null : note,
        );

    if (!mounted) return;

    if (result.isFailure) {
      setState(() {
        _isSubmitting = false;
        _errorText = result.error ?? '申請退貨失敗';
      });
      return;
    }

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final maxQuantity = item.remainingRefundQuantity;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: AlertDialog(
        backgroundColor: const Color(0xFF262A33),
        title: const Text(
          '申請退貨',
          style: TextStyle(color: AppColors.primaryTextColor),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.productNameAtSale,
                style: const TextStyle(
                  color: AppColors.primaryTextColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (item.variantDisplayName.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  item.variantDisplayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.secondaryTextColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _quantityController,
                enabled: !_isSubmitting,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onTapOutside: (_) => FocusScope.of(context).unfocus(),
                style: const TextStyle(color: AppColors.primaryTextColor),
                decoration: _inputDecoration(
                  labelText: '退貨數量',
                  helperText: '最多可退 $maxQuantity 件',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _reasonController,
                enabled: !_isSubmitting,
                onTapOutside: (_) => FocusScope.of(context).unfocus(),
                style: const TextStyle(color: AppColors.primaryTextColor),
                decoration: _inputDecoration(labelText: '退貨原因'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteController,
                enabled: !_isSubmitting,
                maxLines: 3,
                onTapOutside: (_) => FocusScope.of(context).unfocus(),
                style: const TextStyle(color: AppColors.primaryTextColor),
                decoration: _inputDecoration(
                  labelText: '備註（選填）',
                  alignLabelWithHint: true,
                ),
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorText!,
                  style: const TextStyle(color: AppColors.dangerButtonColor),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSubmitting
                ? null
                : () => Navigator.of(context).pop(false),
            child: const Text('取消', style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            onPressed: _isSubmitting || !_isFormValid ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryButtonColor,
              foregroundColor: AppColors.primaryTextColor,
              disabledBackgroundColor: AppColors.mutedTextColor,
              disabledForegroundColor: AppColors.secondaryTextColor,
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('送出'),
          ),
        ],
      ),
    );
  }
}
