// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/constants/colors.dart';
import 'package:flutter_ad_ecommerce/models/treasure_box.dart';
import 'package:flutter_ad_ecommerce/provider/account_provider.dart';
import 'package:flutter_ad_ecommerce/provider/advertisement_provider.dart';
import 'package:flutter_ad_ecommerce/provider/message_stats_provider.dart';
import 'package:flutter_ad_ecommerce/provider/system_provider.dart';
import 'package:flutter_ad_ecommerce/provider/treasure_box_provider.dart';
import 'package:flutter_ad_ecommerce/router/routes.dart';
import 'package:flutter_ad_ecommerce/utils/api_call_manager.dart';
import 'package:flutter_ad_ecommerce/utils/number_formatter_extension.dart';
import 'package:flutter_ad_ecommerce/utils/events.dart';
import 'package:flutter_ad_ecommerce/widgets/badge_count.dart';
import 'package:flutter_ad_ecommerce/widgets/page_status.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  late StreamSubscription _routeChangeSubscription;

  @override
  void initState() {
    super.initState();

    _handleInitHomePage();
    _loadTreasureBoxes();

    _routeChangeSubscription = eventBus.on<RouterChangeEvent>().listen((
      event,
    ) async {
      if (event.to == Routes.homePage && event.to != event.from) {
        log('[Home] re-enter home page');
        final isOutdated = await ApiCallManager.isOutdated('treasure-boxes');
        if (isOutdated) {
          _loadTreasureBoxes(keepPreviousData: false);
        }
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
    _routeChangeSubscription.cancel();
  }

  void _handleInitHomePage() {
    Future.delayed(Duration.zero, () {
      DateTime? termsAcceptedAt = ref
          .read(accountNotifierProvider)
          .termsAcceptedAt;

      log("handle terms accepted, value $termsAcceptedAt");
      if (termsAcceptedAt == null) {
        context.push(Routes.userConsentPage);
      }
    });
  }

  void _loadTreasureBoxes({bool keepPreviousData = true}) {
    Future.delayed(Duration.zero, () async {
      ApiCallManager.updateApiCallTimestamp("treasure-boxes");
      ref
          .read(treasureBoxNotifierProvider.notifier)
          .loadTreasureBoxes(keepPreviousData: keepPreviousData);
    });
  }

  Widget _buildLayout({required Widget child}) {
    return Scaffold(backgroundColor: AppColors.scaffoldBgColor, body: child);
  }

  @override
  Widget build(BuildContext context) {
    final treasureBoxProvider = ref.watch(treasureBoxNotifierProvider);
    final messageStats = ref.watch(messageStatsNotifierProvider);
    // This part is important, you need to watch the following providers so that once you go to another page, it'll get the latest data
    ref.watch(systemNotifierProvider);
    ref.watch(advertisementNotifierProvider);

    if (treasureBoxProvider.hasError ||
        (treasureBoxProvider.isDone && treasureBoxProvider.data!.isEmpty)) {
      return _buildLayout(
        child: PageError(
          treasureBoxProvider.hasError
              ? "Failed to load treasure boxes: ${treasureBoxProvider.error}"
              : "Data not found",
        ),
      );
    }

    if (treasureBoxProvider.isInitial || treasureBoxProvider.isLoading) {
      return _buildLayout(child: PageLoading('載入寶箱中......'));
    }

    final List<TreasureBox> boxes = treasureBoxProvider.data ?? [];
    return _buildLayout(
      child: SafeArea(
        child: Center(
          child: Column(
            children: [
              Stack(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.only(top: 32, bottom: 8),
                    child: Text(
                      '每日寶箱', // Daily Treasure Box
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Positioned(
                    top: Platform.isAndroid ? 24 : 16,
                    right: 12,
                    child: InkWell(
                      onTap: () => context.push(Routes.messagePage),
                      child: Stack(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Icon(
                              Icons.notifications,
                              color: AppColors.primaryTextColor,
                            ),
                          ),
                          if (messageStats.hasData &&
                              messageStats.data!.total > 0)
                            Positioned(
                              top: 2,
                              right: 4,
                              child: BadgeCount(
                                count: messageStats.data!.total,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Builder(
                builder: (context) {
                  final claimableBoxCount = ref.watch(
                    claimableTreasureBoxCountProvider,
                  );
                  final emptyBoxCount = ref.watch(
                    emptyTreasureBoxCountProvider,
                  );
                  return Text(
                    emptyBoxCount == boxes.length
                        ? "您尚未獲得寶箱，快去看廣告獲得寶箱吧！"
                        : claimableBoxCount > 0
                        ? '您有 ${claimableBoxCount.toString()} 個寶箱可以開啟!'
                        : '您已開啟所有寶箱！', // You have 1 treasure box to open!
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  );
                },
              ),
              const SizedBox(height: 24.0),
              // The Grid of treasure boxes
              Expanded(
                child: SizedBox(
                  width: 240,
                  child: GridView.builder(
                    padding: EdgeInsets.only(bottom: 16),
                    shrinkWrap: true,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16.0,
                          mainAxisSpacing: 16.0,
                        ),
                    itemCount: boxes.length,
                    itemBuilder: (context, index) {
                      final box = boxes[index];
                      Color cardColor = box.isOpened
                          ? const Color(0xFFEBC934)
                          : box.isClaimable
                          ? const Color(0xFFE9933E)
                          : const Color(0xFF393E46);

                      return GestureDetector(
                        onTap: box.isClaimable && !box.isOpened
                            ? () async {
                                final result = await ref
                                    .read(treasureBoxNotifierProvider.notifier)
                                    .openBox(box.id);
                                if (result.isSuccess) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        result.data == 0
                                            ? '很抱歉，由於您昨天未觀看廣告，無法獲得金幣'
                                            : '開啟寶箱，獲得${result.data!.formatWithCommas(decimals: 2)}金幣',
                                      ),
                                      backgroundColor: Colors.green,
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                              }
                            : null,
                        child: Card(
                          color: cardColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              // Top-left number
                              Positioned(
                                top: 8,
                                left: 8,
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              // Center content
                              Center(
                                child: box.isOpened || box.isClaimable
                                    ? Image.asset(
                                        box.isOpened
                                            ? 'assets/images/treasure_box_opened.png'
                                            : 'assets/images/treasure_box_claimable.png',
                                        width: 64,
                                        height: 64,
                                        fit: BoxFit.contain,
                                      )
                                    : Text(
                                        "??",
                                        style: TextStyle(
                                          color: Colors.white54,
                                          fontSize: 48,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
