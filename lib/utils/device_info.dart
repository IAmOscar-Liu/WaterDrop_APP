import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

Future<String?> getDeviceId() async {
  final deviceInfo = DeviceInfoPlugin();

  if (Platform.isAndroid) {
    final androidInfo = await deviceInfo.androidInfo;
    return androidInfo.id; // Unique ID for Android
  } else if (Platform.isIOS) {
    final iosInfo = await deviceInfo.iosInfo;
    return iosInfo.identifierForVendor; // Unique ID for iOS
  }

  return null; // Return null if the platform is not supported
}

Future<String?> getDeviceModel() async {
  final deviceInfo = DeviceInfoPlugin();

  if (Platform.isAndroid) {
    final androidInfo = await deviceInfo.androidInfo;
    return androidInfo.model; // Device model for Android
  } else if (Platform.isIOS) {
    final iosInfo = await deviceInfo.iosInfo;
    return iosInfo.utsname.machine; // Device model for iOS
  }

  return null; // Return null if the platform is not supported
}
