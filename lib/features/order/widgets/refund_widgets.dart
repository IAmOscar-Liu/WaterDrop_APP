import 'package:flutter_ad_ecommerce/shared/widgets/app_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ad_ecommerce/constants/colors.dart';
import 'package:flutter_ad_ecommerce/features/order/widgets/order_status_badge.dart';
import 'package:flutter_ad_ecommerce/models/api_enums.dart';
import 'package:flutter_ad_ecommerce/models/order.dart';
import 'package:flutter_ad_ecommerce/provider/order_provider.dart';
import 'package:flutter_ad_ecommerce/provider/refund_request_provider.dart';
import 'package:flutter_ad_ecommerce/features/order/widgets/refund_eligibility_info.dart';
import 'package:flutter_ad_ecommerce/shared/layouts/draggable_details_sheet.dart';
import 'package:flutter_ad_ecommerce/shared/widgets/detail_rows.dart';
import 'package:flutter_ad_ecommerce/utils/coin_utils.dart';
import 'package:flutter_ad_ecommerce/utils/formatter.dart';
import 'package:flutter_ad_ecommerce/utils/number_formatter_extension.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

Future<bool> showCreateRefundDialog(
  BuildContext context, {
  required OrderItem item,
}) async {
  return await showAppDialog<bool>(
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
  ValueChanged<OrderItem>? onOpenChat,
  bool hasPendingRequest = false,
}) {
  final refundItems = item.refundItems;
  final canCreateRefund =
      hasPendingRequest || (item.canRefund && item.remainingRefundQuantity > 0);

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
                  Navigator.of(context).pop();
                  await onCreateRefund(item);
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 16),
                    SizedBox(width: 2),
                    Text(hasPendingRequest ? '確認申請' : '新增'),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        RefundEligibilityInfo(item: item, includeConversionNote: true),
      ],
    ),
    bodyBuilder: (context, scrollController) => ListView.builder(
      controller: scrollController,
      itemCount: refundItems.length,
      itemBuilder: (context, index) {
        return _RefundItemCard(
          refundItem: refundItems[index],
          onOpenChat: onOpenChat == null
              ? null
              : () {
                  Navigator.of(context).pop();
                  onOpenChat(item);
                },
        );
      },
    ),
  );
}

class _RefundItemCard extends StatefulWidget {
  final RefundItem refundItem;
  final VoidCallback? onOpenChat;

  const _RefundItemCard({required this.refundItem, this.onOpenChat});

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
    final original = refundItem.originalRequest;

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (original != null) ...[
            const Text(
              '原始申請',
              style: TextStyle(
                color: AppColors.primaryTextColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            DetailRow(label: '原申請數量:', value: '${original['quantity'] ?? ''}'),
            if (original['reason'] != null)
              DetailRow(label: '原退貨原因:', value: '${original['reason']}'),
            if (original['note'] != null)
              DetailRow(label: '原備註:', value: '${original['note']}'),
            if (logs.isNotEmpty) const Divider(color: AppColors.dividerColor),
            const SizedBox(height: 10),
          ],
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
    final hasHistory =
        refundItem.logs.isNotEmpty || refundItem.originalRequest != null;

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
          if (refundItem.rejectionReason?.trim().isNotEmpty == true)
            DetailRow(label: '拒絕原因:', value: refundItem.rejectionReason!),
          if (refundItem.rejectedAt != null)
            DetailRow(
              label: '拒絕時間:',
              value: Formatter.formatDateTime(refundItem.rejectedAt!.toLocal()),
            ),
          if (refundItem.rejectionDeadlineAfter != null)
            DetailRow(
              label: '重新申請截止時間:',
              value: DateFormat(
                'yyyy-MM-dd HH:mm',
              ).format(refundItem.rejectionDeadlineAfter!.toLocal()),
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
          if (refundItem.status == RefundStatus.pending ||
              refundItem.status == RefundStatus.processing)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: AppColors.goldColor,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(text: '您可以前往'),
                          if (widget.onOpenChat != null)
                            WidgetSpan(
                              alignment: PlaceholderAlignment.baseline,
                              baseline: TextBaseline.alphabetic,
                              child: Semantics(
                                link: true,
                                child: InkWell(
                                  onTap: widget.onOpenChat,
                                  child: const Text(
                                    '聊天室',
                                    style: TextStyle(
                                      color: AppColors.goldColor,
                                      fontSize: 13,
                                      decoration: TextDecoration.underline,
                                      decorationColor: AppColors.goldColor,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          else
                            const TextSpan(text: '聊天室'),
                          const TextSpan(text: '與賣家討論退貨事宜。'),
                        ],
                      ),
                      style: const TextStyle(
                        color: AppColors.goldColor,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (hasHistory) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => setState(() {
                  _showLogs = !_showLogs;
                }),
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

  late OrderItem _item;
  bool _isLoading = true;
  bool _retryOriginal = false;
  bool _isSubmitting = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    _quantityController = TextEditingController(text: '1');
    _reasonController = TextEditingController();
    _noteController = TextEditingController();
    _quantityController.addListener(_handleFormChanged);
    _reasonController.addListener(_handleFormChanged);
    _noteController.addListener(_handleFormChanged);
    _restorePending();
  }

  Future<void> _restorePending() async {
    try {
      final pending = await ref.read(refundRequestProvider).pending(_item.id);
      if (!mounted) return;
      if (pending != null) {
        _quantityController.text = '${pending['quantity']}';
        _reasonController.text = pending['reason'] as String? ?? '';
        _noteController.text = pending['note'] as String? ?? '';
      }
      setState(() {
        _retryOriginal = pending != null;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorText = '無法讀取申請記錄，請稍後再試';
        });
      }
    }
  }

  @override
  void dispose() {
    _noteController.removeListener(_handleFormChanged);
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
    if (_isLoading) return false;
    if (_retryOriginal) return true;
    final quantity = int.tryParse(_quantityController.text.trim()) ?? 0;
    return _item.canRefund &&
        quantity >= 1 &&
        quantity <= _item.remainingRefundQuantity &&
        _reasonController.text.trim().isNotEmpty &&
        _reasonController.text.trim().length <= 2000 &&
        _noteController.text.trim().length <= 5000;
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
    if (_isSubmitting || !_isFormValid) return;
    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });
    final result = await ref
        .read(refundRequestProvider)
        .submit(
          itemId: _item.id,
          quantity: int.tryParse(_quantityController.text.trim()) ?? 1,
          reason: _reasonController.text,
          note: _noteController.text,
        );
    if (!mounted) return;
    ref.invalidate(pendingRefundProvider(_item.id));
    if (result.isSuccess) {
      Navigator.of(context).pop(true);
      return;
    }
    // Refresh eligibility even for business failures. A timeout keeps the
    // original body locked and can be retried regardless of current eligibility.
    final refreshed = await ref
        .read(orderNotifierProvider.notifier)
        .getOrder(orderId: _item.orderId);
    if (!mounted) return;
    setState(() {
      if (refreshed.isSuccess) {
        for (final item in refreshed.data!.items) {
          if (item.id == _item.id) _item = item;
        }
      }
      _isSubmitting = false;
      _retryOriginal = result.uncertain;
      if (refreshed.isFailure && !result.uncertain) _isLoading = true;
      _errorText = result.error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;
    final maxQuantity = item.remainingRefundQuantity;

    return PopScope(
      canPop: !_isSubmitting,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: AlertDialog(
          backgroundColor: AppColors.dialogBgColor,
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
                if (_retryOriginal)
                  const Text(
                    '上次申請結果尚待確認，重試會沿用原申請內容。',
                    style: TextStyle(color: AppColors.secondaryTextColor),
                  ),
                TextField(
                  controller: _quantityController,
                  enabled: !_isSubmitting && !_isLoading && !_retryOriginal,
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
                  maxLength: 2000,
                  enabled: !_isSubmitting && !_isLoading && !_retryOriginal,
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                  style: const TextStyle(color: AppColors.primaryTextColor),
                  decoration: _inputDecoration(labelText: '退貨原因（必填）'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _noteController,
                  maxLength: 5000,
                  enabled: !_isSubmitting && !_isLoading && !_retryOriginal,
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
                RefundEligibilityInfo(item: item, includeConversionNote: true),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: _isSubmitting
                  ? null
                  : () => Navigator.of(context).pop(false),
              child: Text(
                _retryOriginal ? '稍後確認' : '取消',
                style: const TextStyle(color: Colors.white),
              ),
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
                  : Text(_retryOriginal ? '重試原申請' : '送出'),
            ),
          ],
        ),
      ),
    );
  }
}
