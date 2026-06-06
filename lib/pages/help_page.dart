// help_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/constants/colors.dart';
import 'package:flutter_ad_ecommerce/provider/account_provider.dart';
import 'package:flutter_ad_ecommerce/router/routes.dart';
import 'package:flutter_ad_ecommerce/widgets/simple_app_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class HelpPage extends ConsumerWidget {
  const HelpPage({super.key});

  Widget _buildFAQText(String text) {
    return Text(text, style: const TextStyle(color: Colors.white, height: 1.6));
  }

  Widget _buildFAQExpansionTile(
    BuildContext context, {
    required String title,
    required Widget content,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Material(
        color: AppColors.tileColor,
        borderRadius: BorderRadius.circular(8),
        child: Theme(
          data: Theme.of(context).copyWith(
            dividerColor: Colors.transparent,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            expansionTileTheme: const ExpansionTileThemeData(
              iconColor: AppColors
                  .secondaryTextColor, // Color of the arrow when collapsed
              collapsedIconColor: AppColors
                  .secondaryTextColor, // Color of the arrow when expanded
            ),
          ),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            title: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Align(alignment: Alignment.centerLeft, child: content),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBgColor,
      appBar: const SimpleAppBar(title: '客服/幫助中心'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final userId = ref.read(accountNotifierProvider).id;
          context.push(
            Routes.chatroomPage,
            extra: {"title": "水滴客服", "userId": userId},
          );
        },
        backgroundColor: AppColors.infoColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        icon: const Icon(Icons.support_agent),
        label: const Text('聯絡客服'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
            ),
            child: Column(
              children: [
                _buildFAQExpansionTile(
                  context,
                  title: 'Q1：如何獲得金幣？',
                  content: _buildFAQText(
                    '透過參與平台廣告影片任務、每日簽到或完成指定生態活動，即可領取水滴金幣。水滴金幣是您在水滴生態中最重要的價值媒介。',
                  ),
                ),
                _buildFAQExpansionTile(
                  context,
                  title: 'Q2：等級（A0, A1...）具體有什麼好處？',
                  content: _buildFAQText(
                    '等級代表您在生態系統中的貢獻權重。\n\n'
                    '權益加成：等級越高，兌換商品時可使用的「金幣抵扣比例」上限就越高。\n\n'
                    '極致省錢：高等級成員能用更少的現金結合金幣，換取高價值的商品，實現資產價值最大化。\n\n'
                    '晉升機制：您的等級是由您推動的「生態團隊人數」所決定。',
                  ),
                ),
                _buildFAQExpansionTile(
                  context,
                  title: 'Q3：如何透過「生態共建」快速提升等級？',
                  content: _buildFAQText(
                    '水滴生態強調連結與共贏。您可以透過以下方式壯大您的團隊：\n\n'
                    '獲取專屬碼：進入「我的」頁面，複製您的個人推薦碼。\n\n'
                    '連結夥伴：將推薦碼分享給親友，當他們註冊並填寫您的代碼後，即正式成為您的生態團隊成員。\n\n'
                    '共享增益：隨著團隊成員增加，您的等級會自動晉升，解鎖更高的抵扣權限。',
                  ),
                ),
                _buildFAQExpansionTile(
                  context,
                  title: 'Q4：如何修改收件資料？',
                  content: _buildFAQText(
                    '若需更改配送資訊，請至「我的」→「帳號設定與支援」→「寄貨資料」進行編輯。為確保商品準確送達，請在發貨前確認資訊無誤。',
                  ),
                ),
                _buildFAQExpansionTile(
                  context,
                  title: 'Q5：如何一鍵複製ATM轉帳的帳號？',
                  content: _buildFAQText(
                    '我的 → 訂單記錄 → 查看詳情 → 轉帳記錄 → [複製帳號] 銀行帳戶數字',
                  ),
                ),
                _buildFAQExpansionTile(
                  context,
                  title: 'Q6：如果還有其他問題怎麼辦？',
                  content: _buildFAQText(
                    '您可以點擊下方的「聯絡客服」按鈕，我們的生態服務專員將在第一時間為您提供協助。',
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
