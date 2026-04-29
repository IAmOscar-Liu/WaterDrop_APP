import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/constants/app_constants.dart';
import 'package:flutter_ad_ecommerce/constants/colors.dart';
import 'package:flutter_ad_ecommerce/models/advertisement.dart';
import 'package:flutter_ad_ecommerce/provider/advertisement_provider.dart';
import 'package:flutter_ad_ecommerce/provider/cart_provider.dart';
import 'package:flutter_ad_ecommerce/provider/collection_provider.dart';
import 'package:flutter_ad_ecommerce/router/routes.dart';
import 'package:flutter_ad_ecommerce/utils/formatter.dart';
import 'package:flutter_ad_ecommerce/utils/events.dart';
import 'package:flutter_ad_ecommerce/widgets/page_status.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

class AdvertisementPageView extends ConsumerStatefulWidget {
  const AdvertisementPageView({super.key, required this.onFinishPlayingVideos});

  final void Function() onFinishPlayingVideos;

  @override
  ConsumerState<AdvertisementPageView> createState() =>
      _AdvertisementPageViewState();
}

class _AdvertisementPageViewState extends ConsumerState<AdvertisementPageView> {
  late StreamSubscription _routeChangeSubscription;
  late final PageController _pageController;
  final List<VideoPlayerController?> _controllers = [];

  int _currentIndex = 1; // Start at 1 (first real video)
  Duration _currentVideoPosition = Duration.zero;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 1);
    // _pageController.addListener(_onScroll);

    _routeChangeSubscription = eventBus.on<RouterChangeEvent>().listen((
      event,
    ) async {
      if (event.from == Routes.explorePage && event.to != event.from) {
        _controllers[_currentIndex]?.pause();
      }
    });

    _loadAdvertisements();
  }

  @override
  void dispose() {
    super.dispose();
    for (var controller in _controllers) {
      controller?.dispose();
    }
    _pageController.dispose();
    _routeChangeSubscription.cancel();
  }

  void _loadAdvertisements() {
    Future.delayed(Duration.zero, () async {
      log(
        "From advertisement_page_view initState - advertisement status: ${ref.read(advertisementNotifierProvider).status.toString()}",
      );
      // if (ref.read(advertisementNotifierProvider).isInitial) {
      //   final remainingVideoCount = ref
      //       .read(systemNotifierProvider)
      //       .remainingVideoCount;
      //   log("remainingVideoCount: $remainingVideoCount");
      //   await ref
      //       .read(advertisementNotifierProvider.notifier)
      //       .loadAdvertisements(limit: min(20, remainingVideoCount));
      //   // .loadAdvertisements(limit: 10);
      // }
      // Initialize controllers after Advertisements are loaded
      while (!ref.read(advertisementNotifierProvider).isDone) {
        await Future.delayed(Duration(milliseconds: 250));
      }
      _initializeControllers();
    });
  }

  void _initializeControllers() {
    // Clear existing controllers
    for (var controller in _controllers) {
      controller?.dispose();
    }
    _controllers.clear();

    final advertisementList =
        ref.read(advertisementNotifierProvider).data ?? [];
    if (advertisementList.isEmpty) return;

    final circularList = [
      advertisementList.last,
      ...advertisementList,
      advertisementList.first,
    ];

    // Pre-populate the controllers list with nulls.
    // Each controller will be initialized individually.
    _controllers.addAll(
      List<VideoPlayerController?>.filled(circularList.length, null),
    );

    // // Create controllers for circular list
    // for (var i = 0; i < circularList.length; i++) {
    //   // Call the new helper method to initialize each controller with a fallback
    //   _initializeControllerWithFallback(i, circularList[i]);
    // }

    // Lazily initialize only the first few controllers needed for the initial view.
    // We initialize the fake first (index 0), the real first (index 1),
    // and the upcoming second video (index 2).
    _initializeControllerWithFallback(0, circularList[0]);
    _initializeControllerWithFallback(1, circularList[1]);
    if (circularList.length > 2) {
      _initializeControllerWithFallback(2, circularList[2]);
    }
  }

  /// NEW: Helper method to initialize a single controller with fallback logic.
  Future<void> _initializeControllerWithFallback(
    int index,
    Advertisement ad,
  ) async {
    VideoPlayerController controller;

    try {
      // 1. Attempt to load from the network URL first.
      controller = VideoPlayerController.networkUrl(Uri.parse(ad.videoUrl));
      await controller.initialize();
      log("Successfully loaded network video: ${ad.id}");
    } catch (error) {
      log(
        "Failed to load network video for ${ad.id}. Reason: $error. Trying asset fallback.",
      );
      try {
        // 2. If network fails, attempt to load from the asset fallback URL.
        //    IMPORTANT: Make sure your Advertisement model has this field.
        controller = VideoPlayerController.asset(
          ad.fallbackVideoUrl ?? "",
        ); // Assuming this field exists
        await controller.initialize();
        log("Successfully loaded asset fallback for: ${ad.id}");
      } catch (fallbackError) {
        log(
          "FATAL: Asset fallback also failed for ${ad.id}. Reason: $fallbackError",
        );
        // If both fail, we set the controller at this index to null and exit.
        if (mounted) {
          setState(() {
            _controllers[index] = null;
          });
        }
        return;
      }
    }

    // This code runs only if one of the initializations was successful.
    if (!mounted) {
      controller.dispose();
      return;
    }

    // Assign the successfully initialized controller to the list.
    _controllers[index] = controller;

    // The rest of your original setup logic from the `.then()` block goes here.
    controller.setLooping(true);

    if (ad.isLandscape == null) {
      final isLandscape =
          controller.value.size.width > controller.value.size.height;
      ref
          .read(advertisementNotifierProvider.notifier)
          .setAdvertisementIsLandscape(ad.id, isLandscape);
    }

    controller.addListener(() {
      _onVideoPositionChange(ad.id);
    });

    if (index == 1) {
      controller.play(); // Only play after the first real video is initialized
    }

    // Trigger a rebuild to show the initialized video player.
    setState(() {});
  }

  // Helper to get the circular list for display
  List<Advertisement> get circularVideoUrls {
    final advertisementList =
        ref.watch(advertisementNotifierProvider).data ?? [];
    if (advertisementList.isEmpty) return [];
    return [
      advertisementList.last,
      ...advertisementList,
      advertisementList.first,
    ];
  }

  // --- NEW METHOD ---
  void _onPageChanged(int index) {
    final circularList = circularVideoUrls;
    if (circularList.isEmpty) return;

    // --- Handle circular looping ---
    int newIndex = index;
    if (index == 0) {
      // User swiped to the fake page at the beginning
      newIndex = circularList.length - 2; // Real last page index
      _pageController.jumpToPage(newIndex);
      return; // jumpToPage will trigger onPageChanged again
    } else if (index == circularList.length - 1) {
      // User swiped to the fake page at the end
      newIndex = 1; // Real first page index
      _pageController.jumpToPage(newIndex);
      return; // jumpToPage will trigger onPageChanged again
    }

    // --- Pause old and play new video ---
    _controllers[_currentIndex]?.pause();
    _controllers[newIndex]?.play();
    setState(() {
      _currentIndex = newIndex;
    });

    // --- Manage the sliding window of controllers ---

    // Dispose of the controller that is now too far behind
    final disposeIndex = newIndex - 2;
    if (disposeIndex >= 0 && _controllers.length > disposeIndex) {
      log("Disposing controller at index $disposeIndex");
      _controllers[disposeIndex]?.dispose();
      _controllers[disposeIndex] = null;
    }

    // Initialize the controller that is coming up next
    final initializeIndex = newIndex + 1;
    if (initializeIndex < circularList.length) {
      // Only initialize if it's not already being initialized or ready
      if (_controllers[initializeIndex] == null) {
        log("Initializing controller at index $initializeIndex");
        _initializeControllerWithFallback(
          initializeIndex,
          circularList[initializeIndex],
        );
      }
    }
  }

  // void _onScroll() {
  //   final page = _pageController.page;
  //   if (page == null) return;
  //   int newIndex = page.round();

  //   // Circular scroll logic
  //   final advertisementList = ref.read(advertisementNotifierProvider).data ?? [];
  //   if (newIndex == 0) {
  //     // Swiped before first real video, jump to last real video
  //     Future.microtask(() {
  //       _pageController.jumpToPage(advertisementList.length);
  //     });
  //     newIndex = advertisementList.length;
  //   } else if (newIndex == circularVideoUrls.length - 1) {
  //     // Swiped past last real video, jump to first real video
  //     Future.microtask(() {
  //       _pageController.jumpToPage(1);
  //     });
  //     newIndex = 1;
  //   }

  //   // Check if user is trying to swipe to next video
  //   if (newIndex > _currentIndex && newIndex < circularVideoUrls.length - 1) {
  //     final currentProduct = circularVideoUrls[_currentIndex];
  //     if (!currentProduct.isCompleted) {
  //       // This logic is now redundant because of `physics`, but kept for circular scroll jumps
  //       return;
  //     }
  //   }

  //   if (newIndex != _currentIndex) {
  //     _controllers[_currentIndex]?.pause();
  //     // Reset the new video to the beginning and then play
  //     _controllers[newIndex]?.seekTo(Duration.zero);
  //     _controllers[newIndex]?.play();
  //     setState(() {
  //       _currentIndex = newIndex;
  //     });
  //   }
  // }

  void _onVideoPositionChange(String advertisementId) {
    final controller = _controllers[_currentIndex];
    if (controller != null &&
        controller.value.isInitialized &&
        circularVideoUrls[_currentIndex].id == advertisementId) {
      final position = controller.value.position;

      setState(() {
        _currentVideoPosition = position;
      });

      final currentProduct = circularVideoUrls[_currentIndex];

      final totalWatchedMilliseconds = position.inMilliseconds;
      final requiredDuration =
          currentProduct.duration ?? controller.value.duration;
      if (currentProduct.duration == null) {
        ref
            .read(advertisementNotifierProvider.notifier)
            .setAdvertisementDuration(currentProduct.id, requiredDuration);
      }

      if (((totalWatchedMilliseconds >=
                  (requiredDuration.inMilliseconds - 100)) ||
              totalWatchedMilliseconds > 30 * 1000) &&
          (GoRouter.of(context).state.matchedLocation == Routes.explorePage)) {
        ref
            .read(advertisementNotifierProvider.notifier)
            .markAdvertisementAsCompleted(currentProduct.id)
            .then((result) {
              if (result.isSuccess &&
                  result.data == true &&
                  mounted &&
                  !currentProduct.isCompleted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '您已看完${AppConstants.videoCountForClaimingTreasureBox}則廣告，可獲得1個寶箱',
                    ),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            });
      }
    }
  }

  Widget _buildLayout({required Widget child}) {
    return Scaffold(backgroundColor: AppColors.scaffoldBgColor, body: child);
  }

  @override
  Widget build(BuildContext context) {
    final adProvider = ref.watch(advertisementNotifierProvider);

    if (adProvider.hasError) {
      return _buildLayout(
        child: PageError(
          adProvider.hasError
              ? "Failed to load advertisements: ${adProvider.error}"
              : "Data not found",
        ),
      );
    }

    if ((adProvider.isDone && adProvider.data!.isEmpty) ||
        circularVideoUrls.isEmpty) {
      return _buildLayout(
        child: Builder(
          builder: (context) {
            Future.delayed(const Duration(milliseconds: 0), () {
              if (mounted) widget.onFinishPlayingVideos();
            });

            return const SizedBox.shrink();
          },
        ),
      );
    }

    if (adProvider.isInitial || adProvider.isLoading) {
      return _buildLayout(child: PageLoading('載入廣告中......'));
    }

    final currentProduct = circularVideoUrls[_currentIndex];

    // Use the physics property to conditionally enable/disable scrolling
    return PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.vertical,
      itemCount: circularVideoUrls.length,
      // physics: currentProduct.isCompleted
      //     ? const AlwaysScrollableScrollPhysics()
      //     : const NeverScrollableScrollPhysics(),
      physics: const NeverScrollableScrollPhysics(),
      onPageChanged: _onPageChanged, // Connect our new logic
      itemBuilder: (context, index) {
        final controller = index >= _controllers.length
            ? null
            : _controllers[index];
        final product = circularVideoUrls[index];

        if (controller == null || !controller.value.isInitialized) {
          return Stack(
            fit: StackFit.expand,
            children: [
              Container(color: Colors.black),
              Align(
                alignment: Alignment.center,
                child: PageLoading('處理廣告中......'),
              ),
            ],
          );
        }

        // The original code for portrait videos
        return Stack(
          fit: StackFit.expand,
          children: [
            // A black Container to ensure the background is always black
            Container(color: Colors.black),
            FittedBox(
              fit: product.isLandscape == true ? BoxFit.contain : BoxFit.cover,
              child: SizedBox(
                width: controller.value.size.width,
                height: controller.value.size.height,
                child: GestureDetector(
                  onTap: () {
                    if (controller.value.isPlaying) {
                      controller.pause();
                    } else {
                      controller.play();
                    }
                  },
                  child: VideoPlayer(controller),
                ),
              ),
            ),
            if (!controller.value.isPlaying)
              Align(
                alignment: Alignment.center,
                child: IgnorePointer(
                  child: Icon(
                    Icons.play_arrow,
                    size: 64,
                    color: AppColors.mutedTextColor,
                  ),
                ),
              ),
            if (currentProduct.isCompleted)
              Positioned(
                top: 90,
                left: MediaQuery.of(context).size.width / 2 - 90,
                child: SizedBox(
                  width: 180,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (index >= circularVideoUrls.length - 2) {
                        return widget.onFinishPlayingVideos();
                      }
                      _pageController.animateToPage(
                        index + 1,
                        duration: Durations.medium1,
                        curve: Curves.linear,
                      );
                    },
                    icon: const Icon(Icons.campaign, color: Colors.white),
                    label: Text(
                      index >= (circularVideoUrls.length - 2)
                          ? "廣告播放完畢"
                          : '觀看下則廣告',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.navbarIndicatorColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: const BorderSide(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            // if (!currentProduct.isCompleted && currentProduct.duration != null)
            //   Positioned(
            //     top: 90,
            //     left: 0,
            //     right: 0,
            //     child: Align(
            //       alignment: Alignment.center,
            //       child: Builder(
            //         builder: (context) {
            //           final totalWatchedMilliSeconds =
            //               _currentVideoPosition.inMilliseconds;
            //           final requiredMilliSeconds =
            //               currentProduct.duration!.inMilliseconds;
            //           final remainingMilliSeconds =
            //               (requiredMilliSeconds - totalWatchedMilliSeconds)
            //                   .clamp(0, requiredMilliSeconds);
            //           return Text(
            //             '廣告剩餘 ${(remainingMilliSeconds / 1000).ceil()} 秒',
            //             style: const TextStyle(color: Colors.white),
            //           );
            //         },
            //       ),
            //     ),
            //   ),
            Positioned(
              bottom: 150,
              right: 18,
              child: IconButton(
                onPressed: ref.watch(collectionNotifierProvider).isProcessing
                    ? null
                    : () {
                        ref
                            .read(collectionNotifierProvider.notifier)
                            .addCollection(
                              circularVideoUrls[index].productId,
                              productName: circularVideoUrls[index].productName,
                            )
                            .then((result) {
                              if (!mounted) return;
                              final message = result.isSuccess
                                  ? result.data
                                  : result.error;
                              if (message == null) return;
                              // ignore: use_build_context_synchronously
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(message),
                                  backgroundColor: Colors.green,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            });
                      },
                icon: const Icon(Icons.bookmark_add),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.orangeAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 90,
              right: 18,
              child: IconButton(
                onPressed: ref.watch(cartProvider).isProcessing
                    ? null
                    : () {
                        ref
                            .read(cartProvider.notifier)
                            .addCartItem(
                              circularVideoUrls[index].productId,
                              productName: circularVideoUrls[index].productName,
                            )
                            .then((result) {
                              if (!mounted) return;
                              final message = result.isSuccess
                                  ? result.data
                                  : result.error;
                              if (message == null) return;
                              // ignore: use_build_context_synchronously
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(message),
                                  backgroundColor: Colors.green,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            });
                      },
                icon: const Icon(Icons.shopping_cart),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
            if (product.isLandscape == true)
              Positioned(
                bottom: 120,
                left: MediaQuery.of(context).size.width / 2 - 75,
                child: SizedBox(
                  width: 150,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // 1. Pause the controller in the PageView before navigating
                      controller.pause();
                      context
                          .push(
                            Routes.advertisementVideoPlayer,
                            extra: {
                              // 2. Pass the controller instance directly
                              "controller": controller,
                              // 3. Pass the advertisement data as well
                              "advertisement": product,
                            },
                          )
                          .then((value) {
                            // 4. When you return, resume playback in the PageView
                            if (mounted) {
                              controller.play();
                            }
                            if (value is! Map) return;
                            // controller.seekTo(value['position'] as Duration);
                            // controller.play();
                            if (value['isCompleted'] == true) {
                              ref
                                  .read(advertisementNotifierProvider.notifier)
                                  .markAdvertisementAsCompleted(
                                    currentProduct.id,
                                  );
                            }
                          });
                    },
                    icon: const Icon(Icons.fullscreen, color: Colors.white),
                    label: const Text(
                      'Full screen',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: const BorderSide(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.48),
                ),
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 12,
                    right: 12,
                    top: 12,
                    bottom: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (circularVideoUrls[index].avatarUrl == null)
                            CircleAvatar(
                              backgroundColor: Colors.white,
                              radius: 14,
                              child: Text(
                                circularVideoUrls[index].productName[0]
                                    .toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          if (circularVideoUrls[index].avatarUrl != null)
                            CircleAvatar(
                              radius: 14,
                              backgroundImage: NetworkImage(
                                circularVideoUrls[index].avatarUrl!,
                              ),
                            ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              circularVideoUrls[index].title,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              (circularVideoUrls[index].description ??
                                      circularVideoUrls[index].productName)
                                  .replaceAll('\n', ' ')
                                  .replaceAll('\r', ' '),
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          SizedBox(width: 12),
                          if (currentProduct.duration != null)
                            Builder(
                              builder: (context) {
                                final totalWatchedMilliSeconds =
                                    _currentVideoPosition.inMilliseconds;
                                final requiredMilliSeconds =
                                    currentProduct.duration!.inMilliseconds;
                                final remainingMilliSeconds =
                                    (requiredMilliSeconds -
                                            totalWatchedMilliSeconds)
                                        .clamp(0, requiredMilliSeconds);
                                return Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: Formatter.formatDuration(
                                          (remainingMilliSeconds / 1000).ceil(),
                                        ),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontFeatures: [
                                            FontFeature.tabularFigures(),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: VideoProgressIndicator(
                controller,
                allowScrubbing: true,
                colors: const VideoProgressColors(
                  playedColor: Colors.red,
                  backgroundColor: Colors.grey,
                  bufferedColor: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
