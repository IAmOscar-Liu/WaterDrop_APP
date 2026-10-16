import 'package:flutter_ad_ecommerce/constants/app_constants.dart';
import 'package:flutter_ad_ecommerce/provider/notification_sync_provider.dart';
import 'package:flutter_ad_ecommerce/router/chat_route_observer.dart';
import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/constants/colors.dart';
import 'package:flutter_ad_ecommerce/models/api_enums.dart';
import 'package:flutter_ad_ecommerce/models/message.dart';
import 'package:flutter_ad_ecommerce/provider/dio_provider.dart';
import 'package:flutter_ad_ecommerce/provider/message_provider.dart';
import 'package:flutter_ad_ecommerce/router/routes.dart';
import 'package:flutter_ad_ecommerce/shared/layouts/app_scaffold.dart';
import 'package:flutter_ad_ecommerce/shared/widgets/simple_app_bar.dart';
import 'package:flutter_ad_ecommerce/utils/formatter.dart';
import 'package:flutter_ad_ecommerce/utils/list_utils.dart';
import 'package:flutter_ad_ecommerce/utils/result.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SingleMessageDetails extends ConsumerStatefulWidget {
  const SingleMessageDetails({super.key, required this.extra});

  final dynamic extra;

  @override
  ConsumerState<SingleMessageDetails> createState() =>
      _SingleMessageDetailsState();
}

class _SingleMessageDetailsState extends ConsumerState<SingleMessageDetails>
    with RouteAware {
  NotificationSyncController? _sync;
  NotificationDetail? _detail;
  ModalRoute<dynamic>? _route;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (_route != route && route != null) {
      chatRouteObserver.unsubscribe(this);
      _route = route;
      chatRouteObserver.subscribe(this, route);
    }
    _updateVisibility();
  }

  void _updateVisibility() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _detail != null) {
        _sync!.setDetailVisible(_detail!, _route?.isCurrent ?? true);
      }
    });
  }

  @override
  void didPush() => _updateVisibility();
  @override
  void didPushNext() {
    if (_detail != null) _sync!.setDetailVisible(_detail!, false);
  }

  @override
  void didPop() {
    if (_detail != null) _sync!.setDetailVisible(_detail!, false);
  }

  @override
  void didPopNext() => _updateVisibility();
  @override
  void dispose() {
    chatRouteObserver.unsubscribe(this);
    if (_detail != null) _sync!.closeDetail(_detail!);
    super.dispose();
  }

  Message? _message;
  bool _isLoading = true;
  dynamic _error;

  bool _isDeleting = false;
  bool _fallbackScheduled = false;

  void _returnToMessageCenterIfPushed() {
    if (!mounted ||
        _fallbackScheduled ||
        widget.extra is! Map ||
        widget.extra['openedFromNotification'] != true) {
      return;
    }
    _fallbackScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || ModalRoute.of(context)?.isCurrent != true) {
        _fallbackScheduled = false;
        return;
      }
      final messenger = ScaffoldMessenger.of(context);
      context.pushReplacement(Routes.messagePage);
      messenger.showSnackBar(const SnackBar(content: Text('此訊息已刪除或無法存取')));
    });
  }

  String _getTypeLabel(NotificationType type) => type.displayName;

  @override
  void initState() {
    super.initState();
    if (AppConstants.notificationSseEnabled) {
      final extra = widget.extra is Map ? widget.extra as Map : const {};
      final supplied = extra['message'];
      final id = supplied is Message
          ? supplied.id
          : extra['messageId'] as String?;
      if (id == null || id.isEmpty) {
        _error = '無法開啟訊息';
        _isLoading = false;
      } else {
        _sync = ref.read(notificationSyncProvider);
        _detail = _sync!.openDetail(id);
      }
      return;
    }
    if (widget.extra is Map && widget.extra['message'] != null) {
      setState(() {
        _isLoading = false;
        _message = widget.extra['message'];
      });
    } else if (widget.extra is Map && widget.extra['messageId'] is String) {
      _loadSingleMessage(widget.extra['messageId']).then((value) {
        if (!mounted) return;
        if (value.isSuccess) {
          setState(() {
            _isLoading = false;
            _message = value.data!;
          });
        } else {
          setState(() {
            _isLoading = false;
            _error =
                value.error ??
                "Failed to load message ${widget.extra['messageId']}";
          });
        }
      });
    } else {
      // If data is missing, pop immediately
      WidgetsBinding.instance.addPostFrameCallback((_) => context.pop());
      return;
    }
  }

  Future<Result<Message>> _loadSingleMessage(String messageId) async {
    await Future.delayed(Duration.zero);

    final target = (ref.read(messageNotifierProvider).data?.messages ?? [])
        .firstWhereOrNull((p) => p.id == messageId);
    if (target != null) return Result.success(target);

    try {
      final response = await ref
          .read(dioProvider)
          .get("/api/notification/$messageId");
      if (response.statusCode != 200) {
        throw Exception("Failed to load message $messageId");
      }
      final data = response.data;
      if (data['success'] != true || data['data'] is! Map) {
        throw Exception("Failed to get response data");
      }
      Message message = Message.fromApiResponseMap(data['data']);
      return Result.success(message);
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 404) {
        _returnToMessageCenterIfPushed();
      }
      log("Error loading Message $messageId: $e");
      return Result.failure("Error loading Message $messageId: $e");
    }
  }

  Widget _buildLayout({required Widget child}) {
    return AppScaffold(
      backgroundColor: AppColors.primaryColor,
      appBar: SimpleAppBar(title: '訊息詳情'),
      body: child,
    );
  }

  void deleteMessage(Message message) async {
    if (_sync != null) {
      final result = await _sync!.delete(message.id);
      if (!mounted) return;
      if (result.isSuccess) {
        context.pop();
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(result.error ?? '無法刪除訊息')));
      }
      return;
    }
    setState(() {
      _isDeleting = true;
    });

    final response = await ref
        .read(dioProvider)
        .delete(
          "/api/notification",
          data: {
            "notificationIds": [message.id],
          },
        );

    if (response.data['success'] != true) {
      ScaffoldMessenger.of(
        // ignore: use_build_context_synchronously
        context,
      ).showSnackBar(
        SnackBar(
          content: Text('無法刪除訊息'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
      setState(() {
        _isDeleting = false;
      });
      return;
    }
    // ignore: use_build_context_synchronously
    context.pop({'reload': true});
  }

  @override
  Widget build(BuildContext context) {
    if (_detail != null) {
      final sync = ref.watch(notificationSyncProvider);
      _message = sync.item(_detail!.id);
      _isDeleting = sync.deleting(_detail!.id);
      _error = sync.unavailable(_detail!.id) ? '此訊息已刪除或無法存取' : _detail!.error;
      if (sync.unavailable(_detail!.id)) _returnToMessageCenterIfPushed();
      if (_error == null &&
          (sync.connectionStatus == 'unauthorized' ||
              sync.connectionStatus == 'unavailable')) {
        _error = '訊息連線不可用，請重新登入或稍後再試';
      }
      _isLoading = !_detail!.loaded && _error == null;
    }
    if (_error != null) {
      return _buildLayout(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$_error', style: const TextStyle(color: Colors.white)),
              if (_detail != null && !_sync!.unavailable(_detail!.id))
                TextButton(
                  onPressed: () => _sync!.loadDetail(_detail!),
                  child: const Text('重試'),
                ),
            ],
          ),
        ),
      );
    }
    if (_isLoading || _message == null) {
      return _buildLayout(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('載入訊息中......', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      );
    }

    final safeAreaPadding = MediaQuery.of(context).padding;

    return _buildLayout(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: safeAreaPadding.bottom + 24),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      _message!.title,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: AppColors.primaryTextColor,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _getTypeLabel(_message!.type),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                Formatter.formatDateTime(_message!.createdAt),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.secondaryTextColor,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _message!.body,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.primaryTextColor,
                  height: 1.5,
                ),
              ),
              if (_message!.orderId != null &&
                  _message!.orderId!.isNotEmpty &&
                  _message!.metadata?["clickAction"] == "view_order_details")
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: GestureDetector(
                    onTap: () {
                      context.push(
                        Routes.singleOrderDetails,
                        extra: {"orderId": _message!.orderId},
                      );
                    },
                    child: const Text(
                      "查看訂單",
                      style: TextStyle(
                        color: AppColors.infoColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 32),
              if (widget.extra['hideDeleteMessageButton'] != true)
                Padding(
                  padding: EdgeInsetsGeometry.symmetric(horizontal: 24),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isDeleting
                          ? null
                          : () => deleteMessage(_message!),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('刪除訊息'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.dangerButtonColor,
                        foregroundColor: AppColors.primaryTextColor,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
