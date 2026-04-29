import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_ad_ecommerce/models/account_info.dart';
import 'package:flutter_ad_ecommerce/provider/dio_provider.dart';
import 'package:flutter_ad_ecommerce/provider/system_provider.dart';
import 'package:flutter_ad_ecommerce/utils/exception_handler.dart';
import 'package:flutter_ad_ecommerce/utils/result.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'account_provider.g.dart';

@Riverpod(keepAlive: true)
class AccountNotifier extends _$AccountNotifier {
  @override
  AccountInfo build() {
    // Return initial or loaded data here.
    // For now, we'll use placeholder values.
    return AccountInfo.zero();
  }

  void reset() {
    state = AccountInfo.zero();
  }

  Future<Result> loadAccountInfo(User user, {String? timezone}) async {
    try {
      final response = await ref
          .read(dioProvider)
          .post(
            "/api/auth/login",
            data: {
              "oauthId": user.uid,
              "oauthProvider": "google",
              "email": user.email,
              "name": user.displayName,
              "timezone": timezone,
            },
            options: Options(extra: {'requiresAuth': false}),
          );
      final data = response.data;
      if (data['success'] != true ||
          data['data']['user'] == null ||
          data['data']['token'] == null) {
        throw Exception("Failed to get response data");
      }

      state = AccountInfo.fromApiResponseMap(data['data']['user']);
      ref
          .read(systemNotifierProvider.notifier)
          .setAccessToken(data['data']['token']);

      return Result.success();
    } on DioException catch (e) {
      log("Error loading account info: $e");
      return Result.failure(getDioExceptionMessage(e));
    } catch (e) {
      log("Error loading account info: $e");
      return Result.failure("Error loading account info: $e");
    }
  }

  Future<Result> refreshAccountInfo() async {
    try {
      final response = await ref.read(dioProvider).get("/api/auth/profile");
      final data = response.data;
      if (data['success'] != true || data['data'] == null) {
        throw Exception("Failed to get response data");
      }

      state = AccountInfo.fromApiResponseMap(data['data']);

      return Result.success();
    } on DioException catch (e) {
      log("Error loading account info: $e");
      return Result.failure(getDioExceptionMessage(e));
    } catch (e) {
      log("Error loading account info: $e");
      return Result.failure("Error loading account info: $e");
    }
  }

  /// Simulates saving the delivery information
  Future<void> saveDeliveryInfo({
    required String name,
    required String address,
    required String phone,
  }) async {
    try {
      final response = await ref
          .read(dioProvider)
          .put(
            "/api/auth/profile",
            data: {"name": name, "address": address, "phone": phone},
          );
      final data = response.data;
      if (data['success'] != true) {
        throw Exception("Failed to save delivery info");
      }
      refreshAccountInfo();
    } on DioException catch (e) {
      log("Error saving delivery info: ${getDioExceptionMessage(e)}");
    } catch (e) {
      log("Error saving delivery info: $e");
    }
    // state = state.copyWith(name: name, address: address, phone: phone);
  }

  void updateGroupId(String groupId) {
    state = state.copyWith(groupId: groupId);
  }

  Future<Result<bool>> updateTermsAcceptedAt() async {
    try {
      final response = await ref
          .read(dioProvider)
          .post("/api/auth/terms-accepted-at");
      final data = response.data;
      if (data['success'] != true || data["data"] == null) {
        throw Exception("Failed to update terms accepted at");
      }
      state = AccountInfo.fromApiResponseMap(data["data"]);
      return Result.success(true);
    } on DioException catch (e) {
      log("Error updating terms accepted at: ${getDioExceptionMessage(e)}");
      return Result.failure(getDioExceptionMessage(e));
    } catch (e) {
      log("Error updating terms accepted at: $e");
      return Result.failure(e.toString());
    }
  }
}
