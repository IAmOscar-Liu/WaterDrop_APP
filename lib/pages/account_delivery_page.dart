// account_delivery_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/constants/colors.dart';
import 'package:flutter_ad_ecommerce/provider/account_provider.dart';
import 'package:flutter_ad_ecommerce/widgets/keyboard_dismiss_on_tap.dart';
import 'package:flutter_ad_ecommerce/widgets/simple_app_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AccountDeliveryPage extends ConsumerStatefulWidget {
  const AccountDeliveryPage({super.key});

  @override
  ConsumerState<AccountDeliveryPage> createState() =>
      _AccountDeliveryPageState();
}

class _AccountDeliveryPageState extends ConsumerState<AccountDeliveryPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _phoneController;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final accountDeliveryInfo = ref.read(accountNotifierProvider);
    _nameController = TextEditingController(text: accountDeliveryInfo.name);
    _addressController = TextEditingController(
      text: accountDeliveryInfo.address,
    );
    _phoneController = TextEditingController(text: accountDeliveryInfo.phone);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _handleUpdateDelivery() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await ref
          .read(accountNotifierProvider.notifier)
          .saveDeliveryInfo(
            name: _nameController.text,
            address: _addressController.text,
            phone: _phoneController.text,
          );

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('寄貨資料已成功儲存！'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('儲存失敗：$e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildDeliveryInfo() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.containerBgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "寄貨資料",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: AppColors.primaryTextColor,
            ),
          ),
          const Divider(color: AppColors.dividerColor),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInputField(label: '姓名', controller: _nameController),
                const SizedBox(height: 16),
                _buildInputField(label: '地址', controller: _addressController),
                const SizedBox(height: 16),
                _buildInputField(label: '手機號碼', controller: _phoneController),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.secondaryTextColor,
              fontSize: 14,
            ),
          ),
        ),
        TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          cursorColor: AppColors.navbarIndicatorColor,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.fieldInputColor,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            isDense: true,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.transparent),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: AppColors.navbarIndicatorColor,
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBgColor,
      appBar: const SimpleAppBar(title: '帳號設定與支援'),
      body: SafeArea(
        child: KeyboardDismissOnTap(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(top: 24, bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDeliveryInfo(),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleUpdateDelivery,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.navbarIndicatorColor,
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                            )
                          : const Text(
                              '儲存寄貨資料',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
