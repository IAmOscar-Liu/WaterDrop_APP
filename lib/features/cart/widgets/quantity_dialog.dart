import 'package:flutter_ad_ecommerce/shared/widgets/app_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ad_ecommerce/constants/colors.dart';
import 'package:flutter_ad_ecommerce/models/product.dart';
import 'package:flutter_ad_ecommerce/shared/widgets/selection_option_tile.dart';
import 'package:flutter_ad_ecommerce/utils/number_formatter_extension.dart';

class CartItemEditResult {
  final int quantity;
  final ProductVariant variant;

  const CartItemEditResult({required this.quantity, required this.variant});
}

class QuantityDialog extends StatefulWidget {
  const QuantityDialog({
    super.key,
    required this.quantity,
    required this.variants,
    required this.selectedVariant,
    required this.onSubmit,
  });

  final int quantity;
  final List<ProductVariant> variants;
  final ProductVariant selectedVariant;

  /// Runs after dismissal; an error message is shown in the parent Snackbar.
  final Future<String?> Function(CartItemEditResult) onSubmit;

  @override
  State<QuantityDialog> createState() => _QuantityDialogState();
}

class _QuantityDialogState extends State<QuantityDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _quantityController;
  late ProductVariant _selectedVariant;
  bool _isSubmitting = false;

  String? get _quantityError {
    final text = _quantityController.text;
    if (text.isEmpty) return '請輸入數量';
    final quantity = int.tryParse(text);
    if (quantity == null) return '輸入無效';
    if (quantity < 1) return '數量最少為1';
    if (quantity > _selectedVariant.availableStock) {
      return '數量不可超過庫存';
    }
    return null;
  }

  bool get _showVariants =>
      widget.variants.isNotEmpty &&
      !(widget.variants.length == 1 &&
          (widget.variants.single.name?.trim().isEmpty ?? true));

  bool get _canSubmit =>
      !_isSubmitting &&
      _quantityError == null &&
      _selectedVariant.isAvailable &&
      widget.variants.any((variant) => variant.id == _selectedVariant.id);

  @override
  void initState() {
    super.initState();
    // Initialize the text controller with the starting quantity
    _quantityController = TextEditingController(
      text: widget.quantity.toString(),
    );
    _selectedVariant = widget.selectedVariant;
    _quantityController.addListener(_onQuantityChanged);
  }

  void _onQuantityChanged() => setState(() {});

  @override
  void dispose() {
    // Dispose the controller when the widget is removed from the widget tree
    _quantityController.dispose();
    super.dispose();
  }

  // Safely parses the current text value, defaulting to 1 if invalid
  int get _currentValue {
    return int.tryParse(_quantityController.text) ?? 1;
  }

  // Increments the current value in the text field
  void _increment() {
    int currentValue = _currentValue;
    currentValue++;
    _quantityController.text = currentValue.toString();
    _quantityController.selection = TextSelection.fromPosition(
      TextPosition(offset: _quantityController.text.length),
    );
  }

  // Decrements the current value, but not below 1
  void _decrement() {
    int currentValue = _currentValue;
    if (currentValue > 1) {
      currentValue--;
      _quantityController.text = currentValue.toString();
      _quantityController.selection = TextSelection.fromPosition(
        TextPosition(offset: _quantityController.text.length),
      );
    }
  }

  // Validates the form and passes the result back
  Future<void> _submit() async {
    if (!_canSubmit) return;
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final int quantity = int.parse(_quantityController.text);
      setState(() {
        _isSubmitting = true;
      });
      // Capture the page's messenger before the dialog context is disposed.
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      String? error;
      try {
        error = await widget.onSubmit(
          CartItemEditResult(quantity: quantity, variant: _selectedVariant),
        );
      } catch (_) {
        error = '修改失敗，請稍後再試';
      }
      if (error != null && messenger.mounted) {
        messenger.showSnackBar(
          AppSnackBar(
            kind: AppSnackBarKind.error,
            content: Text('修改商品失敗：$error'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSubmitting,
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: AlertDialog(
          backgroundColor: AppColors.dialogBgColor,
          surfaceTintColor: Colors.transparent,
          title: const Text(
            '修改商品',
            style: TextStyle(
              color: AppColors.primaryTextColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_showVariants) ...[
                    const Text(
                      '選擇規格',
                      style: TextStyle(
                        color: AppColors.primaryTextColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Column(
                      children: widget.variants
                          .map((variant) => _buildVariantOptionRow(variant))
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '商品數量',
                        style: TextStyle(
                          color: AppColors.primaryTextColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _selectedVariant.isAvailable
                            ? '庫存 ${_selectedVariant.availableStock}'
                            : '已售完',
                        style: const TextStyle(
                          color: AppColors.secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      IconButton(
                        icon: const Icon(Icons.remove),
                        color: AppColors.primaryTextColor,
                        onPressed: _isSubmitting ? null : _decrement,
                      ),
                      SizedBox(
                        width: 100,
                        child: TextFormField(
                          enabled: !_isSubmitting,
                          controller: _quantityController,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.primaryTextColor,
                            fontWeight: FontWeight.w600,
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            filled: true,
                            fillColor: AppColors.fieldInputColor,
                            border: OutlineInputBorder(),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: AppColors.borderColor,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: AppColors.selectedBorderColor,
                              ),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: AppColors.dangerButtonColor,
                              ),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: AppColors.dangerButtonColor,
                              ),
                            ),
                            contentPadding: EdgeInsets.all(12),
                            errorStyle: TextStyle(
                              color: AppColors.dangerButtonColor,
                            ),
                          ),
                          validator: (_) => _quantityError,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        color: AppColors.primaryTextColor,
                        onPressed: _isSubmitting ? null : _increment,
                      ),
                    ],
                  ),
                  if (_quantityError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _quantityError!,
                      style: const TextStyle(
                        color: AppColors.dangerButtonColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: <Widget>[
            // Cancel Button
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.secondaryTextColor,
              ),
              onPressed: _isSubmitting
                  ? null
                  : () {
                      Navigator.of(context).pop();
                    },
              child: const Text('取消'),
            ),
            // OK Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.navbarIndicatorColor,
                foregroundColor: AppColors.primaryTextColor,
              ),
              onPressed: _canSubmit ? _submit : null,
              child: const Text('確定'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVariantOptionRow(ProductVariant variant) {
    final isSelected = _selectedVariant.id == variant.id;
    final stockText = variant.isAvailable
        ? '庫存 ${variant.availableStock}'
        : '已售完';
    final priceText = variant.price.toDollarsString(prefix: "NT");

    return SelectionOptionTile(
      title: variant.displayName,
      primaryText: priceText,
      secondaryText: stockText,
      isSelected: isSelected,
      strikeThroughTitle: !variant.isAvailable,
      onTap: variant.isAvailable && !_isSubmitting
          ? () => setState(() {
              _selectedVariant = variant;
            })
          : null,
    );
  }
}
