import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:flutter_ad_ecommerce/constants/app_constants.dart';
import 'package:flutter_ad_ecommerce/provider/system_provider.dart';
import 'package:flutter_ad_ecommerce/provider/account_provider.dart';
import 'package:flutter_ad_ecommerce/service/google_auth_service.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'dio_provider.g.dart';

/// REST and SSE share one in-flight token refresh. Never retry through a queued
/// error interceptor: waiting on the retry can deadlock that interceptor queue.
final chatTokenRefreshProvider = Provider<Future<bool> Function()>((ref) {
  Future<bool>? pending;
  Future<bool> refresh() async {
    final user = GoogleAuthService().getCurrentUser();
    if (user == null) return false;
    final previous = ref.read(systemNotifierProvider).accessToken;
    try {
      final timezone = await FlutterTimezone.getLocalTimezone();
      final response =
          await Dio(
            BaseOptions(
              baseUrl: AppConstants.apiBaseUrl,
              connectTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(seconds: 30),
            ),
          ).post(
            '/api/auth/login',
            data: {
              'oauthId': user.uid,
              'oauthProvider': 'google',
              'email': user.email,
              'name': user.displayName,
              'timezone': timezone,
            },
          );
      if (GoogleAuthService().getCurrentUser()?.uid != user.uid ||
          ref.read(systemNotifierProvider).accessToken != previous) {
        return false;
      }
      final token = response.data['data']?['token'];
      if (response.data['success'] != true ||
          token is! String ||
          token.isEmpty) {
        return false;
      }
      ref.read(systemNotifierProvider.notifier).setAccessToken(token);
      return true;
    } catch (_) {
      return false;
    }
  }

  return () => pending ??= refresh().whenComplete(() {
    pending = null;
  });
});

@Riverpod(keepAlive: true)
Dio dio(Ref ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConstants.apiBaseUrl,
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 60),
    ),
  );
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.extra['requiresAuth'] != false) {
          final owner = ref.read(accountNotifierProvider).id;
          final originalOwner = options.extra['authOwner'];
          if (originalOwner != null && originalOwner != owner) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.cancel,
                message: 'Authentication session changed',
              ),
            );
            return;
          }
          options.extra['authOwner'] = owner;
          final token = ref.read(systemNotifierProvider).accessToken;
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        final request = error.requestOptions;
        if (error.response?.statusCode != 401 ||
            request.extra['requiresAuth'] == false ||
            request.extra['isRetry'] == true ||
            request.extra['skipAuthRefresh'] == true) {
          handler.next(error);
          return;
        }
        if (request.extra['authOwner'] !=
            ref.read(accountNotifierProvider).id) {
          handler.next(error);
          return;
        }
        final current = ref.read(systemNotifierProvider).accessToken;
        final alreadyRefreshed =
            current != null &&
            request.headers['Authorization'] != 'Bearer $current';
        if (!alreadyRefreshed && !await ref.read(chatTokenRefreshProvider)()) {
          handler.next(error);
          return;
        }
        request.extra['isRetry'] = true;
        // Multipart bodies are single-use and must be cloned for an auth retry.
        if (request.data is FormData) {
          request.data = (request.data as FormData).clone();
        }
        try {
          handler.resolve(await dio.fetch(request));
        } on DioException catch (retryError) {
          handler.reject(retryError);
        }
      },
    ),
  );
  ref.onDispose(() => dio.close(force: true));
  return dio;
}
