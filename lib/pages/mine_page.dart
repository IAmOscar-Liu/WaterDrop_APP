import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ad_ecommerce/constants/app_constants.dart';
import 'package:flutter_ad_ecommerce/constants/colors.dart';
import 'package:flutter_ad_ecommerce/features/mine/widget/referral_code_dialog.dart';
import 'package:flutter_ad_ecommerce/models/account_info.dart';
import 'package:flutter_ad_ecommerce/models/system.dart';
import 'package:flutter_ad_ecommerce/provider/account_provider.dart';
import 'package:flutter_ad_ecommerce/provider/system_provider.dart';
import 'package:flutter_ad_ecommerce/router/routes.dart';
import 'package:flutter_ad_ecommerce/service/google_auth_service.dart';
import 'package:flutter_ad_ecommerce/utils/formatter.dart';
import 'package:flutter_ad_ecommerce/utils/number_formatter_extension.dart';
import 'package:flutter_ad_ecommerce/widgets/messaging_app_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class MinePage extends ConsumerStatefulWidget {
  const MinePage({super.key});

  @override
  ConsumerState<MinePage> createState() => _MinePageState();
}

class _MinePageState extends ConsumerState<MinePage> {
  @override
  void initState() {
    super.initState();
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: AppColors.primaryTextColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: BorderSide.none,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods remain the same as they are stateless
  Widget _buildInfoRow(String label, String value, {String? warning}) {
    // ... (unchanged helper method)
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.primaryTextColor,
              fontSize: 16,
            ),
          ),
          if (warning == null)
            Text(
              value,
              style: const TextStyle(
                color: AppColors.secondaryTextColor,
                fontSize: 16,
              ),
            ),
          if (warning != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.secondaryTextColor,
                    fontSize: 16,
                  ),
                ),
                Text(
                  warning,
                  style: const TextStyle(
                    color: AppColors.dangerButtonColor,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRowWithCopy(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.primaryTextColor,
              fontSize: 16,
            ),
          ),
          Row(
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: AppColors.secondaryTextColor,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.secondaryButtonColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TextButton.icon(
                  icon: const Icon(
                    Icons.copy,
                    color: AppColors.primaryTextColor,
                    size: 18,
                  ),
                  label: const Text(
                    '複製',
                    style: TextStyle(
                      color: AppColors.primaryTextColor,
                      fontSize: 14,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: value));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('已複製推薦碼'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    // ... (unchanged helper method)
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16.0),
      child: Divider(color: AppColors.lightDividerColor, height: 1),
    );
  }

  void _showReferralCodeDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return ReferralCodeDialog(
          onSuccess: (code) async {
            final result = await ref
                .read(systemNotifierProvider.notifier)
                .sendReferralCode(code);
            final message = (result.isSuccess)
                ? result.data!
                : result.error ?? "無法提交推薦碼";
            _showSnackbar(message);
          },
        );
      },
      // This is important for scrollable dialogs
      // It makes the dialog occupy the full screen height
      // allowing the content to be scrollable if needed.
      useSafeArea: true,
    );
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    AccountInfo accountInfo = ref.watch(accountNotifierProvider);
    System system = ref.watch(systemNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBgColor,
      appBar: MessagingAppBar(title: '會員個人資訊'),
      resizeToAvoidBottomInset: true,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('用戶名稱', accountInfo.name),
            _buildInfoRowWithCopy('推薦碼', accountInfo.referralCode),
            _buildInfoRow(
              '目前金幣',
              accountInfo.coins.formatWithCommas(decimals: 2),
              warning: accountInfo.coinsExpireSoon != null
                  ? "${accountInfo.coinsExpireSoon!.formatWithCommas(decimals: 2)} 即將過期"
                  : null,
            ),
            _buildInfoRow(
              '註冊日期',
              accountInfo.createdAt != null
                  ? Formatter.formatDateTime(accountInfo.createdAt!)
                  : "N/A",
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildQuickActionButton(
                  icon: Icons.bookmark_add,
                  label: "我的收藏",
                  color: Colors.orangeAccent,
                  onTap: () => context.push(Routes.collectionPage),
                ),
                const SizedBox(width: 12),
                _buildQuickActionButton(
                  icon: Icons.list_alt_sharp,
                  label: "訂單記錄",
                  color: AppColors.infoColor,
                  onTap: () => context.push(Routes.orderPage),
                ),
                const SizedBox(width: 12),
                _buildQuickActionButton(
                  icon: Icons.chat,
                  label: "聊天室",
                  color: Colors.green,
                  onTap: () => context.push(Routes.chatroomListPage),
                ),
              ],
            ),
            _buildDivider(),
            _buildInfoRow('用戶等級', accountInfo.level),
            // The team member count is now dynamic, coming from the provider
            if (accountInfo.groupId == null || accountInfo.groupId!.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '用戶團隊人數',
                      style: TextStyle(
                        color: AppColors.primaryTextColor,
                        fontSize: 16,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          '${accountInfo.referralCount + 1} 人',
                          style: const TextStyle(
                            color: AppColors.secondaryTextColor,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.secondaryButtonColor,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: TextButton.icon(
                            icon: const Icon(
                              Icons.group_add,
                              color: AppColors.primaryTextColor,
                              size: 18,
                            ),
                            label: const Text(
                              '加入團隊',
                              style: TextStyle(
                                color: AppColors.primaryTextColor,
                                fontSize: 14,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 0),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: system.isSendingReferralCode
                                ? null
                                : _showReferralCodeDialog,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            else
              _buildInfoRow('用戶團隊人數', '${accountInfo.referralCount + 1} 人'),
            _buildDivider(),
            Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                iconColor: AppColors.secondaryTextColor,
                collapsedIconColor: AppColors.secondaryTextColor,
                title: const Text(
                  '帳號設定與支援',
                  style: TextStyle(
                    color: AppColors.primaryTextColor,
                    fontSize: 16,
                  ),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Column(
                      children: [
                        TextButton(
                          onPressed: () => context.push(Routes.accountDelivery),
                          child: const Text(
                            "寄貨資料",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.push(Routes.help),
                          child: const Text(
                            "客服/幫助中心",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: GoogleAuthService().signOut,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: AppColors.primaryTextColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 2,
                  side: BorderSide.none,
                ),
                child: Text("登出"),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: TextButton(
                onPressed: () {
                  launchUrl(
                    Uri.parse(
                      "${AppConstants.apiBaseUrl}api/file/user-consent",
                    ),
                  );
                },
                child: Text(
                  "用戶同意書",
                  style: TextStyle(color: AppColors.infoColor),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
