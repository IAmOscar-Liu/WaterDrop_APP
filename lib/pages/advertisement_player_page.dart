import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ad_ecommerce/constants/colors.dart';
import 'package:flutter_ad_ecommerce/models/advertisement.dart';
import 'package:flutter_ad_ecommerce/provider/advertisement_provider.dart';
import 'package:flutter_ad_ecommerce/provider/cart_provider.dart';
import 'package:flutter_ad_ecommerce/provider/collection_provider.dart';
import 'package:flutter_ad_ecommerce/utils/formatter.dart';
import 'package:flutter_ad_ecommerce/widgets/page_status.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

class AdvertisementPlayerPage extends ConsumerStatefulWidget {
  final dynamic extra;
  const AdvertisementPlayerPage({super.key, required this.extra});

  @override
  ConsumerState<AdvertisementPlayerPage> createState() =>
      _AdvertisementPlayerPageState();
}

class _AdvertisementPlayerPageState
    extends ConsumerState<AdvertisementPlayerPage> {
  VideoPlayerController? _controller;
  Advertisement? _advertisement;
  Duration _currentVideoPosition = Duration.zero;
  bool _isCompleted = false;

  bool _isControllerVisible = false;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    log('Video Player init from existing controller');
    // Make sure we received the correct data
    if (widget.extra is! Map ||
        widget.extra['controller'] == null ||
        widget.extra['advertisement'] == null) {
      // If data is missing, pop immediately
      WidgetsBinding.instance.addPostFrameCallback((_) => context.pop());
      return;
    }

    // --- MODIFICATION START ---
    // NO MORE _initializeControllers() needed here. We just assign the values.

    _controller = widget.extra['controller'] as VideoPlayerController;
    _advertisement = widget.extra['advertisement'] as Advertisement;
    _currentVideoPosition = _controller!.value.position;

    // Add a listener to THIS page's state update logic
    _controller!.addListener(_onVideoPositionChange);
    _controller!.play();
    // --- MODIFICATION END ---

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  void _onVideoPositionChange() {
    if (!mounted || _advertisement == null) return;

    final controller = _controller;
    if (controller != null && controller.value.isInitialized) {
      final position = controller.value.position;

      setState(() {
        _currentVideoPosition = position;
      });

      // The rest of this method can remain the same...
      final totalWatchedMilliseconds = position.inMilliseconds;
      final requiredDuration =
          _advertisement!.duration ?? controller.value.duration;
      if (_advertisement!.duration == null) {
        ref
            .read(advertisementNotifierProvider.notifier)
            .setAdvertisementDuration(_advertisement!.id, requiredDuration);
      }
      if (totalWatchedMilliseconds >= (requiredDuration.inMilliseconds - 100) ||
          totalWatchedMilliseconds > 30 * 1000) {
        setState(() {
          _isCompleted = true;
        });
      }
    }
  }

  void _showControllerTemporarily() {
    setState(() => _isControllerVisible = true);
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _isControllerVisible = false);
    });
  }

  void _keepControllerVisibleWhileInteracting(bool interacting) {
    if (interacting) {
      if (!_isControllerVisible) {
        setState(() => _isControllerVisible = true);
      }
      _hideTimer?.cancel();
    } else {
      _hideTimer?.cancel();
      _hideTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _isControllerVisible = false);
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
    _hideTimer?.cancel();
    _controller?.removeListener(_onVideoPositionChange);
  }

  @override
  Widget build(BuildContext context) {
    if (_advertisement == null) {
      return const Scaffold(body: PageLoading('載入廣告中......'));
    }

    final safeAreaPadding = MediaQuery.of(context).padding;

    return Scaffold(
      body: _controller == null || !_controller!.value.isInitialized
          ? Stack(
              fit: StackFit.expand,
              children: [
                Container(color: Colors.black),
                Align(
                  alignment: Alignment.center,
                  child: CircularProgressIndicator(),
                ),
              ],
            )
          : Stack(
              fit: StackFit.expand,
              children: [
                Container(color: Colors.black),
                FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: _controller!.value.size.width,
                    height: _controller!.value.size.height,
                    child: GestureDetector(
                      onTap: _showControllerTemporarily,
                      child: VideoPlayer(_controller!),
                    ),
                  ),
                ),
                if (_isControllerVisible) ...[
                  Align(
                    alignment: Alignment.center,
                    child: IconButton(
                      onPressed: () {
                        _showControllerTemporarily();
                        if (_controller!.value.isPlaying) {
                          _controller!.pause();
                        } else {
                          _controller!.play();
                        }
                      },
                      icon: Icon(
                        _controller!.value.isPlaying
                            ? Icons.pause
                            : Icons.play_arrow,
                        size: 48,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.mutedTextColor,
                        foregroundColor: Colors.white,
                        shape: const CircleBorder(),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 20,
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: safeAreaPadding.left + 24),
                          IconButton(
                            onPressed: () {
                              SystemChrome.setPreferredOrientations([
                                DeviceOrientation.portraitUp,
                                DeviceOrientation.portraitDown,
                              ]);
                              context.pop({
                                "position": _currentVideoPosition,
                                "isCompleted": _isCompleted,
                              });
                            },
                            icon: const Icon(
                              Icons.chevron_left,
                              color: Colors.white,
                              size: 36,
                            ),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 12),
                                Text(
                                  _advertisement!.title,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    if (_advertisement!.avatarUrl == null)
                                      CircleAvatar(
                                        backgroundColor: Colors.white,
                                        radius: 14,
                                        child: Text(
                                          _advertisement!.productName[0]
                                              .toUpperCase(),
                                          style: const TextStyle(
                                            color: Colors.black,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    if (_advertisement!.avatarUrl != null)
                                      CircleAvatar(
                                        radius: 14,
                                        backgroundImage: NetworkImage(
                                          _advertisement!.avatarUrl!,
                                        ),
                                      ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        (_advertisement!.description ??
                                                _advertisement!.productName)
                                            .replaceAll('\n', ' ')
                                            .replaceAll('\r', ' '),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 46,
                    left: safeAreaPadding.left + 24,
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: Formatter.formatDuration(
                              (_currentVideoPosition.inMilliseconds / 1000)
                                  .floor(),
                            ),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                          const TextSpan(
                            text: " / ",
                            style: TextStyle(
                              color: Colors.white,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                          TextSpan(
                            text: Formatter.formatDuration(
                              _advertisement!.duration?.inSeconds ?? 30,
                            ),
                            style: const TextStyle(
                              color: Colors.white,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 124,
                    right: safeAreaPadding.right + 50,
                    child: IconButton(
                      onPressed:
                          ref.watch(collectionNotifierProvider).isProcessing
                          ? null
                          : () {
                              _showControllerTemporarily();
                              ref
                                  .read(collectionNotifierProvider.notifier)
                                  .addCollection(
                                    _advertisement!.productId,
                                    productName: _advertisement!.productName,
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
                    bottom: 64,
                    right: safeAreaPadding.right + 50,
                    child: IconButton(
                      onPressed: ref.watch(cartProvider).isProcessing
                          ? null
                          : () {
                              _showControllerTemporarily();
                              ref
                                  .read(cartProvider.notifier)
                                  .addCartItem(
                                    _advertisement!.productId,
                                    productName: _advertisement!.productName,
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
                  Positioned(
                    bottom: 30,
                    left: safeAreaPadding.left + 24,
                    right: safeAreaPadding.right + 24,
                    child: Listener(
                      onPointerDown: (_) =>
                          _keepControllerVisibleWhileInteracting(true),
                      onPointerMove: (_) =>
                          _keepControllerVisibleWhileInteracting(true),
                      onPointerUp: (_) =>
                          _keepControllerVisibleWhileInteracting(false),
                      onPointerCancel: (_) =>
                          _keepControllerVisibleWhileInteracting(false),
                      child: VideoProgressIndicator(
                        _controller!,
                        allowScrubbing: true,
                        colors: const VideoProgressColors(
                          playedColor: Colors.red,
                          backgroundColor: Colors.grey,
                          bufferedColor: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
