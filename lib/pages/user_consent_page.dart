import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/constants/app_constants.dart';
import 'package:flutter_ad_ecommerce/constants/colors.dart';
import 'package:flutter_ad_ecommerce/provider/account_provider.dart';
import 'package:flutter_ad_ecommerce/service/google_auth_service.dart';
import 'package:flutter_ad_ecommerce/widgets/simple_app_bar.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class UserConsentPage extends ConsumerStatefulWidget {
  const UserConsentPage({super.key});

  @override
  ConsumerState<UserConsentPage> createState() => _UserConsentPageState();
}

class _UserConsentPageState extends ConsumerState<UserConsentPage> {
  bool _isCompleted = false;

  Widget _buildLayout({required Widget child}) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.scaffoldBgColor,
        appBar: SimpleAppBar(
          title: '用戶同意書',
          automaticallyImplyLeading: false,
          leading: null,
        ),
        body: SafeArea(child: child),
      ),
    );
  }

  Future<void> _showDisagreeDialog() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("提醒"),
        content: const Text("您若不同意此份同意書，將無法使用本服務"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("取消"),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              GoogleAuthService().signOut();
            },
            child: const Text("確認"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildLayout(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
            child: const Text(
              "請您完整閱讀整份用戶同意書",
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          Expanded(
            child: UserConsentWebview(
              onCompleteReading: () {
                setState(() {
                  _isCompleted = true;
                });
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[800],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      _showDisagreeDialog();
                    },
                    child: const Text("不同意"),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _isCompleted
                        ? () async {
                            ref
                                .read(accountNotifierProvider.notifier)
                                .updateTermsAcceptedAt()
                                .then((result) {
                                  if (result.isSuccess) {
                                    // ignore: use_build_context_synchronously
                                    context.pop();
                                    return;
                                  }
                                  // ignore: use_build_context_synchronously
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text("發生錯誤，請稍後再試"),
                                      backgroundColor:
                                          AppColors.dangerButtonColor,
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                });
                          }
                        : null,
                    child: const Text("同意"),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class UserConsentWebview extends StatelessWidget {
  final Function() onCompleteReading;
  const UserConsentWebview({super.key, required this.onCompleteReading});

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: InAppWebView(
        onPermissionRequest: (controller, request) async {
          return PermissionResponse(
            resources: request.resources,
            action: PermissionResponseAction.GRANT,
          );
        },
        onWebViewCreated: (controller) async {
          await controller.loadUrl(
            urlRequest: URLRequest(
              url: WebUri("${AppConstants.apiBaseUrl}api/file/user-consent"),
            ),
          );

          controller.addJavaScriptHandler(
            handlerName: "complete-reading",
            callback: (args) {
              onCompleteReading();
            },
          );
        },
      ),
    );
  }
}
