// account_delivery_page.dart

import 'package:flutter_ad_ecommerce/shared/layouts/app_scaffold.dart';
import 'package:flutter_ad_ecommerce/shared/widgets/app_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/constants/colors.dart';
import 'package:flutter_ad_ecommerce/provider/account_provider.dart';
import 'package:flutter_ad_ecommerce/provider/system_provider.dart';
import 'package:flutter_ad_ecommerce/router/routes.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_ad_ecommerce/shared/widgets/keyboard_dismiss_on_tap.dart';
import 'package:flutter_ad_ecommerce/shared/widgets/simple_app_bar.dart';
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
  late final TextEditingController _bankAccountController;

  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _resetBank = false;
  String? _selectedBankCode;
  String? _selectedBankName;

  @override
  void initState() {
    super.initState();
    final accountInfo = ref.read(accountNotifierProvider);
    _nameController = TextEditingController(text: accountInfo.name);
    _addressController = TextEditingController(text: accountInfo.address);
    _phoneController = TextEditingController(text: accountInfo.phone);
    _bankAccountController = TextEditingController(
      text: accountInfo.bankAccount,
    );
    _selectedBankCode = accountInfo.bankCode;
    _selectedBankName = accountInfo.bankName;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _bankAccountController.dispose();
    super.dispose();
  }

  void _handleUpdateDelivery() async {
    if (_formKey.currentState?.validate() != true) return;

    final accountInfo = ref.read(accountNotifierProvider);
    final bankCode = _selectedBankCode?.trim();
    final bankAccount = _bankAccountController.text.trim();
    final isSameBankInfo =
        (bankCode ?? '') == (accountInfo.bankCode?.trim() ?? '') &&
        bankAccount == (accountInfo.bankAccount?.trim() ?? '');
    final bankAccountUpdateReminder =
        ref
                .read(systemNotifierProvider)
                .systemInfo?['bankAccountUpdateReminder']
            as String?;
    if (!isSameBankInfo && bankAccountUpdateReminder != null) {
      final confirmed = await _confirmBankAccountUpdate(
        bankAccountUpdateReminder,
      );
      if (!confirmed || !mounted) return;
    }

    setState(() {
      _isLoading = true;
    });

    final result = await ref
        .read(accountNotifierProvider.notifier)
        .saveDeliveryInfo(
          name: _nameController.text.trim(),
          address: _addressController.text.trim(),
          phone: _phoneController.text.trim(),
          bankCode: isSameBankInfo ? null : bankCode,
          bankAccount: isSameBankInfo ? null : bankAccount,
          resetBank: isSameBankInfo ? null : _resetBank,
        );

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      if (result.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('寄貨資訊已成功儲存！'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        await showDialog<void>(
          context: context,
          builder: (context) {
            return AlertDialog(
              backgroundColor: const Color(0xFF262A33),
              title: const Text('儲存失敗', style: TextStyle(color: Colors.white)),
              content: Text(
                result.error ?? '寄貨資訊儲存失敗，請稍後再試。',
                style: const TextStyle(color: Colors.white),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    '確定',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      }
    }
  }

  Future<bool> _confirmBankAccountUpdate(String reminder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF262A33),
          title: const Text('確認銀行帳戶', style: TextStyle(color: Colors.white)),
          content: Text(reminder, style: TextStyle(color: Colors.white)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消', style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('確認送出', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    return confirmed == true;
  }

  String? _requiredValidator(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return '請輸入$label';
    }
    return null;
  }

  String? _bankAccountValidator(String? value) {
    final bankAccount = value?.trim() ?? '';
    final hasBank = _selectedBankCode != null && _selectedBankCode!.isNotEmpty;

    if (bankAccount.isEmpty && !hasBank) return null;
    if (!hasBank) return '請選擇銀行';
    if (bankAccount.isEmpty) return '請輸入銀行帳號';
    return null;
  }

  void _clearBankInfo() {
    setState(() {
      _selectedBankCode = null;
      _selectedBankName = null;
      _bankAccountController.clear();
      _resetBank = true;
    });
  }

  Widget _buildDeliveryInfo() {
    return AppPanel(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            height: 32,
            child: Row(
              children: [
                Icon(
                  Icons.person_outline,
                  size: 20,
                  color: AppColors.primaryTextColor,
                ),
                SizedBox(width: 6),
                Text(
                  "收件人資訊",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: AppColors.primaryTextColor,
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: AppColors.dividerColor),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInputField(
                  label: '姓名',
                  controller: _nameController,
                  isRequired: true,
                  validator: (value) => _requiredValidator(value, '姓名'),
                ),
                const SizedBox(height: 16),
                _buildInputField(
                  label: '地址',
                  controller: _addressController,
                  isRequired: true,
                  keyboardType: TextInputType.multiline,
                  minLines: 3,
                  maxLines: 5,
                  validator: (value) => _requiredValidator(value, '地址'),
                ),
                const SizedBox(height: 16),
                _buildInputField(
                  label: '手機號碼',
                  controller: _phoneController,
                  isRequired: true,
                  keyboardType: TextInputType.phone,
                  validator: (value) => _requiredValidator(value, '手機號碼'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBankInfo() {
    return AppPanel(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 32,
            child: Row(
              children: [
                const Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.account_balance_outlined,
                        size: 20,
                        color: AppColors.primaryTextColor,
                      ),
                      SizedBox(width: 6),
                      Text(
                        "帳戶資訊",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: AppColors.primaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: _isLoading ? null : _clearBankInfo,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Text(
                      '清除',
                      style: TextStyle(
                        color: _isLoading
                            ? AppColors.secondaryTextColor
                            : AppColors.navbarIndicatorColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: AppColors.dividerColor),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: AppColors.secondaryTextColor,
                ),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '帳戶資訊僅供退款使用',
                    style: TextStyle(
                      color: AppColors.secondaryTextColor,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBankSelector(),
                const SizedBox(height: 16),
                _buildInputField(
                  label: '銀行帳號',
                  controller: _bankAccountController,
                  keyboardType: TextInputType.number,
                  validator: _bankAccountValidator,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBankSelector() {
    return TextFormField(
      key: ValueKey('bank-${_selectedBankCode ?? ''}'),
      initialValue: _selectedBankCode == null
          ? ''
          : '$_selectedBankCode ${_selectedBankName ?? ''}',
      readOnly: true,
      enabled: !_isLoading,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      decoration: _inputDecoration().copyWith(
        labelText: '銀行代碼 / 銀行名稱',
        labelStyle: const TextStyle(color: AppColors.secondaryTextColor),
        hintText: '選擇銀行',
        hintStyle: const TextStyle(color: AppColors.secondaryTextColor),
        suffixIcon: const Icon(
          Icons.search,
          color: AppColors.secondaryTextColor,
        ),
      ),
      onTap: () async {
        FocusScope.of(context).unfocus();
        final bank = await context.push<MapEntry<String, String>>(
          Routes.bankSearch,
          extra: _selectedBankCode,
        );
        if (!mounted || bank == null) return;
        setState(() {
          _selectedBankCode = bank.key;
          _selectedBankName = bank.value;
          _resetBank = false;
        });
      },
      validator: (_) {
        if (_bankAccountController.text.trim().isNotEmpty &&
            (_selectedBankCode == null || _selectedBankCode!.isEmpty)) {
          return '請選擇銀行';
        }
        return null;
      },
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    bool isRequired = false,
    TextInputType? keyboardType,
    int? minLines,
    int? maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: RichText(
            text: TextSpan(
              text: label,
              style: const TextStyle(
                color: AppColors.secondaryTextColor,
                fontSize: 14,
              ),
              children: [
                if (isRequired)
                  const TextSpan(
                    text: ' *',
                    style: TextStyle(color: Colors.red),
                  ),
              ],
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          minLines: minLines,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          cursorColor: AppColors.navbarIndicatorColor,
          decoration: _inputDecoration(),
          validator: validator,
          onChanged: (_) {
            if (controller == _bankAccountController) {
              setState(() {
                _resetBank = false;
              });
            }
          },
        ),
      ],
    );
  }

  InputDecoration _inputDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: AppColors.fieldInputColor,
      border: InputBorder.none,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      isDense: true,
      errorStyle: const TextStyle(color: Colors.redAccent),
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.redAccent, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: const SimpleAppBar(title: '寄貨資料'),
      body: SafeArea(
        child: KeyboardDismissOnTap(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(top: 24, bottom: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDeliveryInfo(),
                  const SizedBox(height: 16),
                  _buildBankInfo(),
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
      ),
    );
  }
}
