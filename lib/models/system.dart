// lib/models.dart

import 'package:flutter_ad_ecommerce/models/order.dart';

class System {
  final bool isLoadingDailyStats;
  final bool isPlayingAdvertisements;
  final bool isInExplorePage;
  final bool isInMessagePage;
  final String? currentChatRoomId;

  final int watchedVideoCount;
  final int remainingVideoCount;
  final bool canWatchMoreVideo;
  final List<String>? viewedAds;
  final String? accessToken;
  final String? fcmToken;

  final bool isSendingReferralCode;
  final Order? currentOrder;

  System({
    this.isLoadingDailyStats = true,
    this.isPlayingAdvertisements = false,
    this.isInExplorePage = false,
    this.isInMessagePage = false,
    this.currentChatRoomId,

    this.watchedVideoCount = 0,
    this.remainingVideoCount = 20,
    this.accessToken,
    this.fcmToken,
    this.canWatchMoreVideo = true,
    this.viewedAds,

    this.isSendingReferralCode = false,
    this.currentOrder,
  });

  System copyWith({
    bool? isLoadingDailyStats,
    bool? isPlayingAdvertisements,
    bool? isInExplorePage,
    bool? isInMessagePage,
    String? currentChatRoomId,
    int? watchedVideoCount,
    int? remainingVideoCount,
    String? accessToken,
    String? fcmToken,
    bool? canWatchMoreVideo,
    List<String>? viewedAds,
    bool? isSendingReferralCode,
    Order? currentOrder,

    // Add boolean flags for nullable fields
    bool clearCurrentChatRoomId = false,
    bool clearAccessToken = false,
    bool clearFcmToken = false,
    bool clearCurrentOrder = false,
  }) {
    return System(
      isLoadingDailyStats: isLoadingDailyStats ?? this.isLoadingDailyStats,
      isPlayingAdvertisements:
          isPlayingAdvertisements ?? this.isPlayingAdvertisements,
      isInExplorePage: isInExplorePage ?? this.isInExplorePage,
      isInMessagePage: isInMessagePage ?? this.isInMessagePage,
      watchedVideoCount: watchedVideoCount ?? this.watchedVideoCount,
      remainingVideoCount: remainingVideoCount ?? this.remainingVideoCount,
      canWatchMoreVideo: canWatchMoreVideo ?? this.canWatchMoreVideo,
      viewedAds: viewedAds ?? this.viewedAds,
      isSendingReferralCode:
          isSendingReferralCode ?? this.isSendingReferralCode,

      // Updated logic for nullable fields
      currentChatRoomId: clearCurrentChatRoomId
          ? null
          : (currentChatRoomId ?? this.currentChatRoomId),
      accessToken: clearAccessToken ? null : (accessToken ?? this.accessToken),
      fcmToken: clearFcmToken ? null : (fcmToken ?? this.fcmToken),
      currentOrder: clearCurrentOrder
          ? null
          : (currentOrder ?? this.currentOrder),
    );
  }
}
