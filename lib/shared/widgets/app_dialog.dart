import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/constants/colors.dart';

/// Common surface and readable controls for all app dialogs.
class AppDialogs {
  static const theme = DialogThemeData(
    backgroundColor: AppColors.dialogBgColor,
    surfaceTintColor: Colors.transparent,
    titleTextStyle: TextStyle(
      color: AppColors.primaryTextColor,
      fontSize: 20,
      fontWeight: FontWeight.w600,
    ),
    contentTextStyle: TextStyle(
      color: AppColors.primaryTextColor,
      fontSize: 14,
      height: 1.5,
    ),
  );

  static ThemeData themeFor(ThemeData base) => base.copyWith(
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.infoColor,
      onPrimary: Colors.black,
      secondary: AppColors.greenColor,
      onSecondary: Colors.black,
      surface: AppColors.dialogBgColor,
      onSurface: AppColors.primaryTextColor,
      error: AppColors.dangerButtonColor,
    ),
    dialogTheme: theme,
    canvasColor: AppColors.dialogBgColor,
    cardColor: AppColors.dialogBgColor,
    dividerColor: AppColors.dividerColor,
    datePickerTheme: const DatePickerThemeData(
      backgroundColor: AppColors.dialogBgColor,
      surfaceTintColor: Colors.transparent,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.primaryTextColor,
      displayColor: AppColors.primaryTextColor,
    ),
    iconTheme: const IconThemeData(color: AppColors.secondaryTextColor),
    disabledColor: AppColors.mutedTextColor,
    unselectedWidgetColor: AppColors.secondaryTextColor,
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primaryTextColor,
        disabledForegroundColor: AppColors.mutedTextColor,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryButtonColor,
        foregroundColor: AppColors.primaryTextColor,
        disabledForegroundColor: AppColors.secondaryTextColor,
        disabledBackgroundColor: AppColors.borderColor,
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: AppColors.fieldInputColor,
      labelStyle: TextStyle(color: AppColors.secondaryTextColor),
      hintStyle: TextStyle(color: AppColors.mutedTextColor),
      floatingLabelStyle: TextStyle(color: AppColors.infoColor),
      errorStyle: TextStyle(color: AppColors.dangerButtonColor),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: AppColors.borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: AppColors.infoColor),
      ),
      errorBorder: OutlineInputBorder(
        borderSide: BorderSide(color: AppColors.dangerButtonColor),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderSide: BorderSide(color: AppColors.dangerButtonColor),
      ),
    ),
  );
}

Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  bool useSafeArea = true,
  bool useRootNavigator = true,
  Color? barrierColor,
  String? barrierLabel,
  RouteSettings? routeSettings,
}) => showDialog<T>(
  context: context,
  barrierDismissible: barrierDismissible,
  useSafeArea: useSafeArea,
  useRootNavigator: useRootNavigator,
  barrierColor: barrierColor,
  barrierLabel: barrierLabel,
  routeSettings: routeSettings,
  builder: (context) => Theme(
    data: AppDialogs.themeFor(Theme.of(context)),
    child: Builder(builder: builder),
  ),
);
