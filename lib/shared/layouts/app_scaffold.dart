import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/constants/colors.dart';
import 'package:flutter_ad_ecommerce/shared/widgets/keyboard_dismiss_on_tap.dart';

/// Common page surface. Insets and keyboard dismissal are opt-in so pages keep
/// control of their scrolling, navigation, and keyboard behavior.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.backgroundColor = AppColors.scaffoldBgColor,
    this.resizeToAvoidBottomInset,
    this.useSafeArea = false,
    this.dismissKeyboardOnTap = false,
    this.floatingActionButton,
  });

  final Widget body;
  final PreferredSizeWidget? appBar;
  final Color backgroundColor;
  final bool? resizeToAvoidBottomInset;
  final bool useSafeArea;
  final bool dismissKeyboardOnTap;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    Widget content = body;
    if (dismissKeyboardOnTap) {
      content = KeyboardDismissOnTap(child: content);
    }
    if (useSafeArea) content = SafeArea(child: content);

    return Scaffold(
      appBar: appBar,
      backgroundColor: backgroundColor,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      floatingActionButton: floatingActionButton,
      body: content,
    );
  }
}
