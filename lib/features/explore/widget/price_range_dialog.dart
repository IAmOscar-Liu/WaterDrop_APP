import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ad_ecommerce/constants/colors.dart';

class PriceRangeDialog extends StatefulWidget {
  const PriceRangeDialog({
    super.key,
    this.maxPrice,
    this.minPrice,
    required this.onSuccess,
  });

  final int? minPrice;
  final int? maxPrice;
  final Function({int? minPrice, int? maxPrice}) onSuccess;

  @override
  State<PriceRangeDialog> createState() => _PriceRangeDialogState();
}

class _PriceRangeDialogState extends State<PriceRangeDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _minPriceController = TextEditingController();
  final TextEditingController _maxPriceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Initialize text controllers with provided price values
    _minPriceController.text = widget.minPrice != null
        ? widget.minPrice.toString()
        : '';
    _maxPriceController.text = widget.maxPrice != null
        ? widget.maxPrice.toString()
        : '';

    // Add listeners to update the UI when text changes
    _minPriceController.addListener(() => setState(() {}));
    _maxPriceController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    // Dispose controllers to free up resources
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  void _submit() {
    // Validate the form. If it's valid, proceed.
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      // Parse text to integers. Empty text becomes null.
      final int? minPrice = int.tryParse(_minPriceController.text);
      final int? maxPrice = int.tryParse(_maxPriceController.text);

      // Call the success callback with the new values
      widget.onSuccess(minPrice: minPrice, maxPrice: maxPrice);

      // Close the dialog
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    // GestureDetector to dismiss keyboard when tapping outside of a text field
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: AlertDialog(
        title: const Text('選擇價格區間'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Minimum Price Text Field
              TextFormField(
                controller: _minPriceController,
                keyboardType: TextInputType.number,
                // Only allow digits
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: '最低價格',
                  hintText: '例如 100',
                  // Show a clear button if the text field is not empty
                  suffixIcon: _minPriceController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _minPriceController.clear();
                          },
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              // Maximum Price Text Field
              TextFormField(
                controller: _maxPriceController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: '最高價格',
                  hintText: '例如 500',
                  // Show a clear button if the text field is not empty
                  suffixIcon: _maxPriceController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _maxPriceController.clear();
                          },
                        )
                      : null,
                ),
                validator: (value) {
                  // Validation logic
                  if (_minPriceController.text.isNotEmpty &&
                      _maxPriceController.text.isNotEmpty) {
                    final int? minPrice = int.tryParse(
                      _minPriceController.text,
                    );
                    final int? maxPrice = int.tryParse(
                      _maxPriceController.text,
                    );

                    if (minPrice != null &&
                        maxPrice != null &&
                        maxPrice < minPrice) {
                      return '最高價格必須大於最低價格';
                    }
                  }
                  return null; // Return null if validation is successful
                },
              ),
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
