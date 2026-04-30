import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/constants/colors.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppVersionText extends StatelessWidget {
  const AppVersionText({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final packageInfo = snapshot.data;
        if (packageInfo == null) {
          return const SizedBox.shrink();
        }

        return Text(
          '版本: ${packageInfo.version}+${packageInfo.buildNumber}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.mutedTextColor, fontSize: 14),
        );
      },
    );
  }
}
