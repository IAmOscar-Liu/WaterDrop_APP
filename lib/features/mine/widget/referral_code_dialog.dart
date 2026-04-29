// ignore_for_file: use_build_context_synchronously

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/constants/colors.dart';
import 'package:flutter_ad_ecommerce/provider/dio_provider.dart';
import 'package:flutter_ad_ecommerce/utils/exception_handler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ReferralCodeDialog extends ConsumerStatefulWidget {
  const ReferralCodeDialog({super.key, required this.onSuccess});

  final Function(String) onSuccess;

  @override
  ConsumerState<ReferralCodeDialog> createState() => _ReferralCodeDialogState();
}

class _ReferralCodeDialogState extends ConsumerState<ReferralCodeDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _controller = TextEditingController();

  // --- MODIFIED: Added state variables for loading and async errors ---
  bool _isLoading = false;
  String? _asyncError;

  @override
  void initState() {
    super.initState();
    _controller.text = '';
    // No need to call setState in the listener anymore
    // _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // --- MODIFIED: _submit is now async and handles the API call ---
  Future<void> _submit() async {
    // Clear previous async errors before validating
    setState(() {
      _asyncError = null;
    });

    // 1. Run synchronous validation first.
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 2. Perform the asynchronous API call.
      final response = await ref
          .read(dioProvider)
          .get("/api/auth/referral/${_controller.text}");

      if (response.data['success'] != true) {
        throw Exception("推薦碼無效");
      }
      widget.onSuccess(_controller.text);
      Navigator.of(context).pop();
    } on DioException catch (e) {
      setState(() {
        _asyncError = getDioExceptionMessage(e);
      });
    } catch (e) {
      // Handle exceptions during the API call
      setState(() {
        _asyncError = "推薦碼無效";
      });
    } finally {
      // 5. Stop the loading indicator.
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: AlertDialog(
        title: const Text('輸入推薦碼'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _controller,
                autocorrect: false,
                textCapitalization: TextCapitalization.none,
                decoration: InputDecoration(
                  labelText: '推薦碼',
                  border: const OutlineInputBorder(),
                  // --- MODIFIED: Display the async error here ---
                  errorText: _asyncError,
                  suffixIcon: _controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => _controller.clear(),
                        )
                      : null,
                ),
                // --- MODIFIED: Validator is now synchronous ---
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "請輸入邀請碼";
                  }
                  // No more async validation here.
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.navbarIndicatorColor,
              foregroundColor: AppColors.primaryTextColor,
            ),
            // --- MODIFIED: Disable button during API call ---
            onPressed: _isLoading ? null : _submit,
            child: _isLoading
                // Show a loading indicator
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('提交'),
          ),
        ],
      ),
    );
  }
}
