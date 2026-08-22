import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ad_ecommerce/constants/colors.dart';
import 'package:flutter_ad_ecommerce/models/product.dart';
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
    required this.onSuccess,
  });

  final int quantity;
  final List<ProductVariant> variants;
  final ProductVariant selectedVariant;
  final ValueChanged<CartItemEditResult> onSuccess;

  @override
  State<QuantityDialog> createState() => _QuantityDialogState();
}

class _QuantityDialogState extends State<QuantityDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _quantityController;
  late ProductVariant _selectedVariant;

  @override
  void initState() {
    super.initState();
    // Initialize the text controller with the starting quantity
    _quantityController = TextEditingController(
      text: widget.quantity.toString(),
    );
    _selectedVariant = widget.selectedVariant;
  }

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
  void _submit() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final int quantity = int.parse(_quantityController.text);
      widget.onSuccess(
        CartItemEditResult(quantity: quantity, variant: _selectedVariant),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: AlertDialog(
        backgroundColor: AppColors.containerBgColor,
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
                if (widget.variants.length > 1) ...[
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
                const Text(
                  '商品數量',
                  style: TextStyle(
                    color: AppColors.primaryTextColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    IconButton(
                      icon: const Icon(Icons.remove),
                      color: AppColors.primaryTextColor,
                      onPressed: _decrement,
                    ),
                    SizedBox(
                      width: 100,
                      child: TextFormField(
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
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '請輸入數量';
                          }
                          final int? quantity = int.tryParse(value);
                          if (quantity == null) {
                            return '輸入無效';
                          }
                          if (quantity < 1) {
                            return '數量最少為1';
                          }
                          return null;
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      color: AppColors.primaryTextColor,
                      onPressed: _increment,
                    ),
                  ],
                ),
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
            child: const Text('取消'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          // OK Button
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.navbarIndicatorColor,
              foregroundColor: AppColors.primaryTextColor,
            ),
            onPressed: _submit,
            child: const Text('確定'),
          ),
        ],
      ),
    );
  }

  Widget _buildVariantOptionRow(ProductVariant variant) {
    final isSelected = _selectedVariant.id == variant.id;
    final stockText = '庫存 ${variant.availableStock}';
    final priceText = variant.price.toDollarsString(prefix: "NT");

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => setState(() => _selectedVariant = variant),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.navbarIndicatorColor.withValues(alpha: 0.18)
                : AppColors.tileColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? AppColors.selectedBorderColor
                  : AppColors.borderColor,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: isSelected
                    ? AppColors.infoColor
                    : AppColors.secondaryTextColor,
                size: 22,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  variant.displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.primaryTextColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    priceText,
                    style: const TextStyle(
                      color: AppColors.goldColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    stockText,
                    style: const TextStyle(
                      color: AppColors.secondaryTextColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
