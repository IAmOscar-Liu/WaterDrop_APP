import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ad_ecommerce/constants/colors.dart';

class QuantityDialog extends StatefulWidget {
  const QuantityDialog({
    super.key,
    required this.quantity,
    required this.onSuccess,
  });

  final int quantity;
  final Function(int) onSuccess;

  @override
  State<QuantityDialog> createState() => _QuantityDialogState();
}

class _QuantityDialogState extends State<QuantityDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _quantityController;

  @override
  void initState() {
    super.initState();
    // Initialize the text controller with the starting quantity
    _quantityController = TextEditingController(
      text: widget.quantity.toString(),
    );
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
      widget.onSuccess(quantity);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: AlertDialog(
        title: const Text('輸入商品數量'),
        content: Form(
          key: _formKey,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Decrement Button
              IconButton(icon: const Icon(Icons.remove), onPressed: _decrement),
              // Quantity Text Field
              SizedBox(
                width: 100,
                child: TextFormField(
                  controller: _quantityController,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.all(12),
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
                    return null; // Return null if validation is successful
                  },
                ),
              ),
              // Increment Button
              IconButton(icon: const Icon(Icons.add), onPressed: _increment),
            ],
          ),
        ),
        actions: <Widget>[
          // Cancel Button
          TextButton(
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
}
