// lib/member_info_provider.dart
import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter_ad_ecommerce/models/order.dart';
import 'package:flutter_ad_ecommerce/models/system.dart';
import 'package:flutter_ad_ecommerce/provider/account_provider.dart';
import 'package:flutter_ad_ecommerce/provider/dio_provider.dart';
import 'package:flutter_ad_ecommerce/utils/exception_handler.dart';
import 'package:flutter_ad_ecommerce/utils/parse_utils.dart';
import 'package:flutter_ad_ecommerce/utils/result.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'system_provider.g.dart';

@Riverpod(keepAlive: true)
class SystemNotifier extends _$SystemNotifier {
  @override
  System build() {
    // This is the initial state of the member information from the image
    return System();
  }

  Future<Result<String>> sendFcmToken(
    String fcmToken, {
    String? deviceId,
  }) async {
    try {
      final response = await ref
          .read(dioProvider)
          .post(
            "/api/auth/device-token",
            data: {"fcmToken": fcmToken, "deviceId": deviceId},
          );
      final data = response.data;

      if (data['success'] != true) throw Exception("Fail to send fcm token");

      state = state.copyWith(fcmToken: data['data']['fcmToken']);

      return Result.success(data['data']['fcmToken']);
    } catch (e) {
      return Result.failure(
        e is DioException
            ? getDioExceptionMessage(e)
            : "Failed to send fcmToken: $e",
      );
    }
  }

  Future<Result<bool>> clearFcmToken(String? deviceId) async {
    try {
      final response = await ref
          .read(dioProvider)
          .delete("/api/auth/device-token", data: {"deviceId": deviceId});
      final data = response.data;

      if (data['success'] != true) throw Exception("Fail to send fcm token");

      state = state.copyWith(clearFcmToken: true);

      return Result.success(true);
    } catch (e) {
      return Result.failure(
        e is DioException
            ? getDioExceptionMessage(e)
            : "Failed to delete fcmToken: $e",
      );
    }
  }

  Future<Result<System>> getAdDailyStats() async {
    state = state.copyWith(isLoadingDailyStats: true);
    try {
      final response = await ref.read(dioProvider).get("/api/auth/daily-stats");

      final data = response.data;
      if (data['success'] != true) throw Exception("Fail to get response data");

      state = state.copyWith(
        // real data
        watchedVideoCount: ParseUtils.parseInt(data['data']['totalViews']),
        remainingVideoCount: ParseUtils.parseInt(
          data['data']['remainingViews'],
        ),
        canWatchMoreVideo: data['data']['canWatchMore'] == true,
        viewedAds: List<String>.from(data['data']['viewedAds'] ?? []),
        isPlayingAdvertisements: data['data']['canWatchMore'] == true,

        // // fake data
        // watchedVideoCount: 18,
        // remainingVideoCount: 2,
        // canWatchMoreVideo: true,
        // isPlayingAdvertisements: true,
      );

      return Result.success(state);
    } on DioException catch (e) {
      log('Error loading ad daily statistics: $e');
      return Result.failure(getDioExceptionMessage(e));
    } catch (e) {
      log('Error loading ad daily statistics: $e');
      return Result.failure('Error loading ad daily statistics: $e');
    } finally {
      state = state.copyWith(isLoadingDailyStats: false);
    }
  }

  void setDailyVideoStats({
    bool? isLoadingDailyStats,
    bool? isPlayingAdvertisements,
    int? watchedVideoCount,
    int? remainingVideoCount,
    bool? canWatchMoreVideo,
  }) {
    state = state.copyWith(
      isLoadingDailyStats: isLoadingDailyStats,
      isPlayingAdvertisements: isPlayingAdvertisements,
      watchedVideoCount: watchedVideoCount,
      remainingVideoCount: remainingVideoCount,
      canWatchMoreVideo: canWatchMoreVideo,
    );
  }

  void setWatchedVideoCount(int value) {
    state = state.copyWith(watchedVideoCount: value);
  }

  void setCanWatchMoreVideo(bool value) {
    state = state.copyWith(canWatchMoreVideo: value);
  }

  void setAccessToken(String accessToken) {
    state = state.copyWith(accessToken: accessToken);
  }

  void setIsInExplorePage(bool isInExplorePage) {
    state = state.copyWith(isInExplorePage: isInExplorePage);
  }

  void setIsInMessagePage(bool isInMessagePage) {
    state = state.copyWith(isInMessagePage: isInMessagePage);
  }

  void setCurrentChatRoomId(String? chatRoomId) {
    if (chatRoomId != null) {
      state = state.copyWith(currentChatRoomId: chatRoomId);
    } else {
      state = state.copyWith(clearCurrentChatRoomId: true);
    }
  }

  void setCurrentOrder(Order? order) {
    if (order != null) {
      state = state.copyWith(currentOrder: order);
    } else {
      state = state.copyWith(clearCurrentOrder: true);
    }
  }

  Future<Result<String>> sendReferralCode(String code) async {
    if (state.isSendingReferralCode) {
      return Result.failure("推薦碼發送中，請稍後......");
    }
    try {
      state = state.copyWith(isSendingReferralCode: true);

      // // For testing
      // await Future.delayed(Duration(seconds: 1));
      // state = state.copyWith(hasUsedReferralCode: true);
      // return Result.success("It works");

      final response = await ref
          .read(dioProvider)
          .post("/api/auth/join-group", data: {"referralCode": code});

      if (response.data['success'] == true) {
        ref
            .read(accountNotifierProvider.notifier)
            .updateGroupId(response.data['data']['groupId']);
        return Result.success("推薦碼提交成功");
      } else {
        return Result.failure(response.data['message']);
      }
    } on DioException catch (e) {
      log('Error checking referral code: $e');
      return Result.failure(getDioExceptionMessage(e));
    } catch (e) {
      log('Error checking referral code: $e');
      return Result.failure("$e");
    } finally {
      state = state.copyWith(isSendingReferralCode: false);
    }
  }
}
