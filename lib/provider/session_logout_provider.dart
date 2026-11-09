import 'package:flutter_ad_ecommerce/shared/widgets/app_snackbar.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_ad_ecommerce/provider/account_provider.dart';
import 'package:flutter_ad_ecommerce/provider/app_badge_provider.dart';
import 'package:flutter_ad_ecommerce/provider/system_provider.dart';
import 'package:flutter_ad_ecommerce/service/google_auth_service.dart';
import 'package:flutter_ad_ecommerce/utils/device_info.dart';
import 'package:flutter_ad_ecommerce/utils/result.dart';

final deviceRegistrationProvider = Provider<DeviceRegistration>((ref) {
  return DeviceRegistration(
    owner: () {
      final account = ref.read(accountNotifierProvider);
      return account.oauthId.isEmpty ? null : account.id;
    },
    registerToken: (token) async {
      final owner = ref.read(accountNotifierProvider).id;
      final deviceId = await getDeviceId();
      if (ref.read(accountNotifierProvider).id != owner) {
        return Result.failure('Account changed');
      }
      return ref
          .read(systemNotifierProvider.notifier)
          .sendFcmToken(token, deviceId: deviceId);
    },
    removeToken: () async => ref
        .read(systemNotifierProvider.notifier)
        .clearFcmToken(await getDeviceId()),
  );
});

/// Serialize registration and logout so a late token refresh cannot re-register
/// the old user after their token was removed.
class DeviceRegistration {
  DeviceRegistration({
    required this.owner,
    required this.registerToken,
    required this.removeToken,
  });
  final String? Function() owner;
  final Future<Result<String>> Function(String) registerToken;
  final Future<Result<bool>> Function() removeToken;
  Future<void> _pending = Future.value();
  bool signingOut = false;

  Future<void> register(String token) {
    final user = owner();
    if (user == null || signingOut) return Future.value();
    return _pending = _pending
        .then((_) async {
          if (signingOut || owner() != user) return;
          await registerToken(token);
        })
        .catchError((Object _) {
          /* Next login/token refresh can retry. */
        });
  }

  Future<Result<bool>> unregister() async {
    signingOut = true;
    final user = owner();
    await _pending;
    if (user == null) return Result.success(true);
    if (owner() != user) return Result.failure('帳號已變更，請重試');
    try {
      return await removeToken();
    } catch (_) {
      return Result.failure('無法解除通知註冊，請重試');
    }
  }
}

final firebaseSignOutProvider = Provider<Future<void> Function()>(
  (ref) =>
      () => GoogleAuthService().signOut(),
);
final sessionLogoutProvider = Provider<Future<Result<bool>> Function()>((ref) {
  Future<Result<bool>>? pending;
  Future<Result<bool>> signOut() async {
    final registration = ref.read(deviceRegistrationProvider);
    try {
      final result = await registration.unregister();
      if (result.isFailure) return Result.failure('無法解除通知註冊，請檢查網路後重試登出');
      await ref.read(firebaseSignOutProvider)();
      ref.read(appBadgeProvider).configureSession(null, foreground: false);
      return Result.success(true);
    } catch (_) {
      return Result.failure('無法登出，請稍後重試');
    } finally {
      registration.signingOut = false;
    }
  }

  return () => pending ??= signOut().whenComplete(() => pending = null);
});

Future<void> signOutWithFeedback(BuildContext context, WidgetRef ref) async {
  final result = await ref.read(sessionLogoutProvider)();
  if (context.mounted && result.isFailure) {
    ScaffoldMessenger.of(context).showSnackBar(
      AppSnackBar(
        kind: AppSnackBarKind.error,
        content: Text(result.error ?? '無法登出'),
      ),
    );
  }
}
