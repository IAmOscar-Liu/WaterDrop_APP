import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_ad_ecommerce/constants/app_constants.dart';
import 'package:flutter_ad_ecommerce/provider/system_provider.dart';
import 'package:flutter_ad_ecommerce/service/google_auth_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

// This line is required for the generator to run.
part 'dio_provider.g.dart';

@riverpod
Dio dio(DioRef ref) {
  // Create a new Dio instance.
  final dio = Dio();

  // You can configure Dio with base options, interceptors, etc.
  dio.options.baseUrl = AppConstants.apiBaseUrl;
  dio.options.connectTimeout = const Duration(seconds: 60);
  dio.options.receiveTimeout = const Duration(seconds: 60);

  // Use QueuedInterceptorsWrapper to lock and unlock requests.
  // This prevents multiple concurrent requests from all trying to refresh
  // the token at the same time if they all fail with a 401.
  dio.interceptors.add(
    QueuedInterceptorsWrapper(
      // ATTACH TOKEN TO REQUEST
      onRequest: (options, handler) {
        // Check for a custom option to determine if auth is needed.
        // Defaults to true if the option is not provided.
        final bool requiresAuth =
            options.extra['requiresAuth'] as bool? ?? true;

        if (requiresAuth) {
          final accessToken = ref.read(systemNotifierProvider).accessToken;
          if (accessToken != null && accessToken.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $accessToken';
          }
        }
        print('REQUEST[${options.method}] => PATH: ${options.path}');
        return handler.next(options);
      },

      // LOG SUCCESSFUL RESPONSES
      onResponse: (response, handler) {
        print(
          'RESPONSE[${response.statusCode}] => PATH: ${response.requestOptions.path}',
        );
        return handler.next(response);
      },

      // HANDLE 401 AND REFRESH TOKEN
      onError: (e, handler) async {
        final bool requiresAuth =
            e.requestOptions.extra['requiresAuth'] as bool? ?? true;
        final bool isRetry =
            e.requestOptions.extra['isRetry'] as bool? ?? false;

        final User? user = GoogleAuthService().getCurrentUser();

        // Only handle 401 errors on authorized requests that are not retries.
        if (e.response?.statusCode == 401 &&
            requiresAuth &&
            !isRetry &&
            user != null) {
          print('INTERCEPTOR: Received 401, attempting to refresh token.');

          try {
            final response = await Dio().post(
              "${AppConstants.apiBaseUrl}/api/auth/google",
              data: {
                "sub": user.uid,
                "email": user.email,
                "name": user.displayName,
                "picture": user.photoURL,
                // "referral_code": "OOR665", // 可選
              },
            );

            if (response.statusCode == 200 &&
                response.data['success'] == true &&
                response.data['data']['user'] != null &&
                response.data['data']['token'] != null) {
              final newAccessToken = response.data['data']['token'].toString();
              print('INTERCEPTOR: Token refreshed successfully.');

              final requestOptions = e.requestOptions;
              requestOptions.headers['Authorization'] =
                  'Bearer $newAccessToken';
              requestOptions.extra['isRetry'] = true; // Mark as a retry

              print(
                'INTERCEPTOR: Retrying original request to ${requestOptions.path}',
              );
              final retryResponse = await dio.fetch(requestOptions);

              // IMPORTANT: Resolve the handler with the new response
              return handler.resolve(retryResponse);
            }
          } on DioException catch (refreshError) {
            // If the refresh token request fails, reject the original error.
            print('INTERCEPTOR: Refresh token failed - $refreshError');
            // Optionally, you could log the user out here.
            return handler.reject(e);
          }
        }

        // For all other errors, just pass them through.
        return handler.next(e);
      },
    ),
  );
  // Return the configured Dio instance.
  return dio;
}

/// To use this provider, you would first need to run the build_runner:
/// flutter pub run build_runner build
///
/// Then, in your code (e.g., in another provider or a widget), you can access it like this:
///
/// final dio = ref.watch(dioProvider);
/// final response = await dio.get('/some_endpoint');
