import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:device_info_plus/device_info_plus.dart';

// Persist an installation identity; Android build IDs are shared by devices.
Future<String>? _installationId;
Future<String> getDeviceId() =>
    _installationId ??= _loadInstallationId().catchError((Object e) {
      _installationId = null;
      throw e;
    });

Future<String> _loadInstallationId() async {
  final preferences = await SharedPreferences.getInstance();
  final existing = preferences.getString('pushInstallationId');
  if (existing != null && existing.isNotEmpty) return existing;
  final id = const Uuid().v4();
  if (!await preferences.setString('pushInstallationId', id)) {
    throw StateError('Cannot persist push installation ID');
  }
  return id;
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
