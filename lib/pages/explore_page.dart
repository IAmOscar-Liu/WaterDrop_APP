import 'dart:async';
import 'dart:developer';
import 'dart:math' show min;

import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/constants/colors.dart';
import 'package:flutter_ad_ecommerce/features/explore/widget/advertisement_page_view.dart';
import 'package:flutter_ad_ecommerce/provider/advertisement_provider.dart';
import 'package:flutter_ad_ecommerce/provider/system_provider.dart';
import 'package:flutter_ad_ecommerce/router/routes.dart';
import 'package:flutter_ad_ecommerce/shared/layouts/app_scaffold.dart';
import 'package:flutter_ad_ecommerce/shared/widgets/messaging_app_bar.dart';
import 'package:flutter_ad_ecommerce/shared/widgets/page_status.dart';
import 'package:flutter_ad_ecommerce/utils/api_call_manager.dart';
import 'package:flutter_ad_ecommerce/utils/events.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ExplorePage extends ConsumerStatefulWidget {
  const ExplorePage({super.key});

  @override
  ConsumerState<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends ConsumerState<ExplorePage>
    with WidgetsBindingObserver {
  late StreamSubscription _routeChangeSubscription;
  Timer? _dailyRefreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleDailyRefresh();

    // Future.delayed(Duration.zero, () {
    //   log(
    //     "From explore initState - ${ref.read(systemNotifierProvider).remainingVideoCount}",
    //   );
    //   log(
    //     "From explore initState - advertisement status: ${ref.read(advertisementNotifierProvider).status.toString()}",
    //   );
    // });

    _routeChangeSubscription = eventBus.on<RouterChangeEvent>().listen((
      event,
    ) async {
      // log(
      //   "[Explore] RouterChangeEvent received: from ${event.from} to ${event.to}",
      // );
      if (event.to == Routes.explorePage && event.to != event.from) {
        log('[Explore] re-enter explore page');
        final isOutdated = await ApiCallManager.isOutdated('advertisements');
        if (isOutdated) {
          _reloadAdDailyStats();
          return;
        }
        final system = ref.read(systemNotifierProvider);
        if (!system.isPlayingAdvertisements && system.canWatchMoreVideo) {
          // if (!_isPlayingVideos) {
          _reloadAdDailyStats();
        }
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dailyRefreshTimer?.cancel();
    _routeChangeSubscription.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _reloadAdDailyStatsIfOutdated();
      _scheduleDailyRefresh();
    }
  }

  Future<void> _reloadAdDailyStatsIfOutdated() async {
    final isOutdated = await ApiCallManager.isOutdated('advertisements');
    if (mounted && isOutdated) _reloadAdDailyStats();
  }

  void _scheduleDailyRefresh() {
    _dailyRefreshTimer?.cancel();
    final now = DateTime.now();
    final nextRefresh = ApiCallManager.nextDailyRefreshAt(now);
    _dailyRefreshTimer = Timer(nextRefresh.difference(now), () {
      if (!mounted) return;
      _reloadAdDailyStats();
      _scheduleDailyRefresh();
    });
  }

  void _reloadAdDailyStats() async {
    Future.delayed(Duration.zero, () async {
      ApiCallManager.updateApiCallTimestamp("advertisements");

      final result = await ref
          .read(systemNotifierProvider.notifier)
          .getAdDailyStats();
      if (result.isSuccess && result.data!.canWatchMoreVideo) {
        ref
            .read(advertisementNotifierProvider.notifier)
            .loadAdvertisements(
              limit: min(20, result.data!.remainingVideoCount),
            );
      }
    });
  }

  void _showVideoCompleteFailure() {
    if (!mounted ||
        GoRouter.of(context).state.matchedLocation != Routes.explorePage) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('廣告回報失敗，正在重新整理廣告列表，請稍後再試。'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final system = ref.watch(systemNotifierProvider);
    final advertisementProvider = ref.watch(advertisementNotifierProvider);

    if (system.isLoadingDailyStats || advertisementProvider.isLoading) {
      return AppScaffold(body: PageLoading('載入廣告中......'));
    }

    if (system.isPlayingAdvertisements) {
      return AdvertisementPageView(
        onVideoCompleteFailed: _showVideoCompleteFailure,
        onFinishPlayingVideos: () => ref
            .read(systemNotifierProvider.notifier)
            .setDailyVideoStats(isPlayingAdvertisements: false),
      );
    }

    return AppScaffold(
      appBar: MessagingAppBar(title: "廣告"),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                '您已看完今日全部的廣告，快去「市集」血拼一發吧！',
                style: TextStyle(color: Colors.white),
              ),
            ),
            SizedBox(height: 24),
            SizedBox(
              width: 200,
              child: ElevatedButton(
                onPressed: () {
                  context.go(Routes.productPage);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navbarIndicatorColor,
                  foregroundColor: AppColors.primaryTextColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 2,
                  side: BorderSide.none,
                ),
                child: Text("前往市集"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
