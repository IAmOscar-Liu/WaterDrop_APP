// help_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/constants/colors.dart';
import 'package:flutter_ad_ecommerce/widgets/simple_app_bar.dart';

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBgColor,
      appBar: const SimpleAppBar(title: '客服/幫助中心'),
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
                  title: '如何獲得金幣?',
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '主要方式:',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      RichText(
                        text: const TextSpan(
                          style: TextStyle(color: Colors.white),
                          children: [
                            TextSpan(
                              text:
                                  '1. 看完兩則廣告的完整內容 (即達到廣告指定時長) 後, 即可獲得一個「寶箱」. 在「寶箱」頁面開啟寶箱可獲得大量金幣.',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                _buildFAQExpansionTile(
                  context,
                  title: '等級 (A0, A1...) 有什麼用?',
                  content: const Text(
                    '等級越高, 在兌換商品時可使用的金幣抵扣百分比就越高, 能讓您省下更多現金. 等級由您的團隊人數決定.',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                _buildFAQExpansionTile(
                  context,
                  title: '如何增加團隊人數來提升等級?',
                  content: const Text(
                    '您可以將您的專屬「推薦碼」(在「我的」頁面查看) 分享給朋友, 當他們註冊時填寫您的推薦碼, 他們就會成為您的團隊成員. 目前APP中的「增加團隊人數」按鈕為測試功能, 方便您體驗不同等級的效果.',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                _buildFAQExpansionTile(
                  context,
                  title: '如何修改收件資料?',
                  content: const Text(
                    '請在「我的」頁面找到「帳號設定與支援」區塊, 展開後即可看到「寄件資料」區塊, 填寫或修改您的姓名、地址和電話, 然後點擊「儲存寄貨資料」按鈕即可.',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                _buildFAQExpansionTile(
                  context,
                  title: '如果還有其他問題怎麼辦?',
                  content: RichText(
                    text: TextSpan(
                      style: const TextStyle(color: Colors.white),
                      children: [
                        const TextSpan(text: '若您的問題不在此列表中, 歡迎寄送電子郵件至我們的客服信箱'),
                        // TextSpan(
                        //   text: 'support@example.com',
                        //   style: const TextStyle(
                        //     color: Colors.white,
                        //     decoration: TextDecoration.underline,
                        //   ),
                        // ),
                        const TextSpan(text: ', 我們將盡快為您解答.'),
                      ],
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
