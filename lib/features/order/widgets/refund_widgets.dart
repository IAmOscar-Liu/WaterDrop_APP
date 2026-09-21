import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ad_ecommerce/constants/colors.dart';
import 'package:flutter_ad_ecommerce/features/order/widgets/order_status_badge.dart';
import 'package:flutter_ad_ecommerce/models/order.dart';
import 'package:flutter_ad_ecommerce/provider/order_provider.dart';
import 'package:flutter_ad_ecommerce/shared/layouts/draggable_details_sheet.dart';
import 'package:flutter_ad_ecommerce/shared/widgets/detail_rows.dart';
import 'package:flutter_ad_ecommerce/utils/coin_utils.dart';
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

  showDraggableDetailsSheet<void>(
    context: context,
    headerBuilder: (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
        const SizedBox(height: 8),
        const _RefundConversionNotice(),
      ],
    ),
    bodyBuilder: (context, scrollController) => ListView.builder(
      controller: scrollController,
      itemCount: refundItems.length,
      itemBuilder: (context, index) {
        return _RefundItemCard(refundItem: refundItems[index]);
      },
    ),
  );
}

class _RefundItemCard extends StatefulWidget {
  final RefundItem refundItem;

  const _RefundItemCard({required this.refundItem});

  @override
  State<_RefundItemCard> createState() => _RefundItemCardState();
}

class _RefundItemCardState extends State<_RefundItemCard> {
  bool _showLogs = false;

  RefundItem get refundItem => widget.refundItem;

  String _refundCoinsText() {
    final expectedUnits =
        CoinUtils.toCoinUnits(refundItem.coins) +
        CoinUtils.toCoinUnits(refundItem.cashRemainderCoins);
    final returnableCoins = refundItem.returnableCoins;

    if (returnableCoins != null) {
      final returnableUnits = CoinUtils.toCoinUnits(returnableCoins);
      final unavailableUnits = expectedUnits - returnableUnits;
      final value = CoinUtils.fromCoinUnits(returnableUnits).formatCoinValue();
      if (unavailableUnits > 0) {
        return '$value (${CoinUtils.fromCoinUnits(unavailableUnits).formatCoinValue()} 已逾期，無法退還)';
      }
      return value;
    }
    return CoinUtils.fromCoinUnits(expectedUnits).formatCoinValue();
  }

  int get _cashRefundAmount =>
      refundItem.cashRefundAmount ??
      ((refundItem.paidRefundAmount ?? 0) + refundItem.extraRefundAmount)
          .floor();

  Widget _buildLogRow(RefundLog log, bool isLast) {
    final message = log.message?.trim();

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 7),
                decoration: const BoxDecoration(
                  color: AppColors.infoColor,
                  shape: BoxShape.circle,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 1, color: AppColors.dividerColor),
                ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          Formatter.formatDateTime(log.createdAt),
                          style: const TextStyle(
                            color: AppColors.secondaryTextColor,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      RefundStatusBadge(status: log.status),
                    ],
                  ),
                  if (message?.isNotEmpty == true) ...[
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 5,
                            height: 5,
                            margin: const EdgeInsets.only(top: 7),
                            decoration: BoxDecoration(
                              color: AppColors.secondaryTextColor.withValues(
                                alpha: 0.8,
                              ),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              message!,
                              style: const TextStyle(
                                color: AppColors.primaryTextColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogHistory() {
    final logs = refundItem.logs;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
      decoration: BoxDecoration(
        color: AppColors.containerBgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        children: [
          for (var index = 0; index < logs.length; index++)
            _buildLogRow(logs[index], index == logs.length - 1),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reason = refundItem.reason?.trim();
    final note = refundItem.note?.trim();
    final hasLogs = refundItem.logs.isNotEmpty;

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
          DetailRow(label: '退貨數量:', value: refundItem.quantity.toString()),
          DetailRow(
            label: '現金退款:',
            value: _cashRefundAmount.toDollarsString(prefix: "NT"),
          ),
          DetailRow(label: '退還金幣:', value: _refundCoinsText()),
          if (reason?.isNotEmpty == true)
            DetailRow(label: '退貨原因:', value: reason!),
          if (note?.isNotEmpty == true) DetailRow(label: '備註:', value: note!),
          DetailRow(
            label: '最後更新時間:',
            value: Formatter.formatDateTime(refundItem.updatedAt),
          ),
          if (hasLogs) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _showLogs = !_showLogs;
                  });
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.infoColor,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
                icon: Icon(
                  _showLogs ? Icons.expand_less : Icons.history,
                  size: 18,
                ),
                label: Text(_showLogs ? '收合記錄' : '查看記錄'),
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: _buildLogHistory(),
              crossFadeState: _showLogs
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 180),
            ),
          ],
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
              const SizedBox(height: 12),
              const _RefundConversionNotice(),
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

class _RefundConversionNotice extends StatelessWidget {
  const _RefundConversionNotice();

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline, color: AppColors.warningColor, size: 16),
        SizedBox(width: 6),
        Expanded(
          child: Text(
            '退款金額的小數部分將依 NT\$1 = 10 金幣轉換，並合併計入退還金幣。',
            style: TextStyle(
              color: AppColors.warningColor,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
