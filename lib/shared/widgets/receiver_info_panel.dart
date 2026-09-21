import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/constants/colors.dart';
import 'package:flutter_ad_ecommerce/models/account_info.dart';
import 'package:flutter_ad_ecommerce/shared/widgets/section_panel.dart';

/// Read-only shipping and bank details shared by cart and payment checkout.
class ReceiverInfoPanel extends StatelessWidget {
  const ReceiverInfoPanel({super.key, required this.accountInfo});

  final AccountInfo accountInfo;

  @override
  Widget build(BuildContext context) {
    return SectionPanel(
      title: "寄貨資料",
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.person_outline,
                size: 18,
                color: AppColors.primaryTextColor,
              ),
              SizedBox(width: 6),
              Text(
                "收件人資訊",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryTextColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "姓名：${accountInfo.name.isEmpty ? "尚未填寫" : accountInfo.name}",
            style: const TextStyle(color: AppColors.secondaryTextColor),
          ),
          Text(
            "地址：${(accountInfo.address == null || accountInfo.address!.isEmpty) ? "尚未填寫" : accountInfo.address}",
            style: const TextStyle(color: AppColors.secondaryTextColor),
          ),
          Text(
            "手機號碼：${(accountInfo.phone == null || accountInfo.phone!.isEmpty) ? "尚未填寫" : accountInfo.phone}",
            style: const TextStyle(color: AppColors.secondaryTextColor),
          ),
          const SizedBox(height: 16),
          const Row(
            children: [
              Icon(
                Icons.account_balance_outlined,
                size: 18,
                color: AppColors.primaryTextColor,
              ),
              SizedBox(width: 6),
              Text(
                "帳戶資訊",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryTextColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "銀行：${(accountInfo.bankCode == null || accountInfo.bankCode!.isEmpty || accountInfo.bankName == null || accountInfo.bankName!.isEmpty) ? "尚未填寫" : "${accountInfo.bankCode} ${accountInfo.bankName}"}",
            style: const TextStyle(color: AppColors.secondaryTextColor),
          ),
          Text(
            "銀行帳號：${(accountInfo.bankAccount == null || accountInfo.bankAccount!.isEmpty) ? "尚未填寫" : accountInfo.bankAccount}",
            style: const TextStyle(color: AppColors.secondaryTextColor),
          ),
          const SizedBox(height: 12),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: AppColors.mutedTextColor,
              ),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  "如需修改，請至「我的」→「帳號設定與支援」→「寄貨資料」頁面進行變更",
                  style: TextStyle(color: AppColors.mutedTextColor),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
