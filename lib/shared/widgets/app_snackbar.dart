import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/constants/colors.dart';

enum AppSnackBarKind {
  success,
  error,
  info;

  Color get backgroundColor => switch (this) {
    success => AppColors.snackbarSuccessColor,
    error => AppColors.snackbarErrorColor,
    info => AppColors.snackbarInfoColor,
  };

  IconData get icon => switch (this) {
    success => Icons.check_circle_outline,
    error => Icons.error_outline,
    info => Icons.info_outline,
  };
}

/// Select a semantic kind instead of assigning colors at individual call sites.
class AppSnackBar extends SnackBar {
  AppSnackBar({
    super.key,
    required Widget content,
    this.kind = AppSnackBarKind.info,
    super.duration,
    super.action,
  }) : super(
         backgroundColor: kind.backgroundColor,
         content: Row(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             Icon(kind.icon, color: Colors.white, size: 20),
             const SizedBox(width: 10),
             Expanded(
               child: DefaultTextStyle(
                 style: const TextStyle(
                   color: Colors.white,
                   fontSize: 14,
                   height: 1.4,
                 ),
                 child: content,
               ),
             ),
           ],
         ),
       );

  final AppSnackBarKind kind;

  static const theme = SnackBarThemeData(
    backgroundColor: AppColors.snackbarInfoColor,
    contentTextStyle: TextStyle(color: Colors.white, fontSize: 14),
    actionTextColor: Colors.white,
    disabledActionTextColor: Colors.white70,
  );
}
