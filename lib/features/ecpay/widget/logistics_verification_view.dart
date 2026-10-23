import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/constants/colors.dart';
import 'package:flutter_ad_ecommerce/features/ecpay/logistics_verification_result.dart';
import 'package:flutter_ad_ecommerce/models/account_info.dart';
import 'package:flutter_ad_ecommerce/provider/account_provider.dart';
import 'package:flutter_ad_ecommerce/provider/dio_provider.dart';
import 'package:flutter_ad_ecommerce/router/chat_route_observer.dart';
import 'package:flutter_ad_ecommerce/shared/widgets/page_status.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LogisticsVerificationView extends ConsumerStatefulWidget {
  const LogisticsVerificationView({
    super.key,
    required this.logisticsType,
    required this.onSuccess,
    required this.onBack,
    required this.onEdit,
  });

  final String logisticsType;
  final VoidCallback onSuccess;
  final VoidCallback onBack;
  final VoidCallback onEdit;

  @override
  ConsumerState<LogisticsVerificationView> createState() =>
      _LogisticsVerificationViewState();
}

class _LogisticsVerificationViewState
    extends ConsumerState<LogisticsVerificationView>
    with RouteAware {
  CancelToken? _cancelToken;
  Timer? _retryTimer;
  ModalRoute<dynamic>? _route;
  int _sequence = 0;
  int _retrySeconds = 0;
  bool _loading = true;
  bool _accountChanged = false;
  String? _error;

  Object _receiverKey(AccountInfo account) =>
      (account.id, account.oauthId, account.name, account.phone, account.email);

  @override
  void initState() {
    super.initState();
    ref.listenManual(accountNotifierProvider, (previous, next) {
      if (previous == null || _receiverKey(previous) == _receiverKey(next)) {
        return;
      }
      _accountChanged =
          _accountChanged ||
          previous.id != next.id ||
          previous.oauthId != next.oauthId;
      _invalidate(_accountChanged ? '帳號已變更，請返回購物車重新確認。' : '收件資訊已變更，請重新驗證。');
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _loading) _verify();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null && route != _route) {
      chatRouteObserver.unsubscribe(this);
      _route = route;
      chatRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didUpdateWidget(covariant LogisticsVerificationView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.logisticsType != widget.logisticsType) {
      _invalidate('配送設定已變更，請重新驗證。');
    }
  }

  void _invalidate(String message) {
    ++_sequence;
    _cancelToken?.cancel('Checkout verification invalidated');
    _cancelToken = null;
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = message;
    });
  }

  @override
  void didPushNext() => _invalidate('請重新驗證物流資料後繼續結帳。');

  @override
  void didPop() => _invalidate('結帳已中止。');

  Future<void> _verify() async {
    if (_cancelToken != null ||
        _retrySeconds > 0 ||
        _accountChanged ||
        !(_route?.isCurrent ?? true)) {
      return;
    }
    final account = ref.read(accountNotifierProvider);
    if (account.id.isEmpty) {
      _invalidate('請返回並重新登入後再結帳。');
      return;
    }
    final receiverKey = _receiverKey(account);
    final type = widget.logisticsType;
    final sequence = ++_sequence;
    final cancelToken = CancelToken();
    _cancelToken = cancelToken;
    setState(() {
      _loading = true;
      _error = null;
    });
    LogisticsVerificationResult result;
    try {
      final response = await ref
          .read(dioProvider)
          .post(
            '/api/ecpay/express/test/validate',
            data: {
              'type': type,
              'ReceiverName': account.name,
              'ReceiverCellPhone': account.phone,
              'ReceiverEmail': account.email,
            },
            options: Options(receiveTimeout: const Duration(seconds: 30)),
            cancelToken: cancelToken,
          );
      result = LogisticsVerificationResult.fromResponse(response);
    } catch (error) {
      result = LogisticsVerificationResult.fromError(error);
    }
    if (!mounted || sequence != _sequence || cancelToken.isCancelled) return;
    _cancelToken = null;
    if (_receiverKey(ref.read(accountNotifierProvider)) != receiverKey ||
        widget.logisticsType != type ||
        !(_route?.isCurrent ?? true)) {
      _invalidate('結帳資訊已變更，請重新驗證。');
      return;
    }
    if (result.validated) {
      // Invalidate this attempt before the parent transitions to delivery settings.
      ++_sequence;
      widget.onSuccess();
      return;
    }
    setState(() {
      _loading = false;
      _error = result.message;
      _retrySeconds = result.retryAfterSeconds;
    });
    _retryTimer?.cancel();
    if (_retrySeconds > 0) {
      _retryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return timer.cancel();
        setState(() => _retrySeconds--);
        if (_retrySeconds <= 0) timer.cancel();
      });
    }
  }

  void _leave(VoidCallback action) {
    _invalidate('請重新驗證物流資料後繼續結帳。');
    action();
  }

  @override
  void dispose() {
    ++_sequence;
    _cancelToken?.cancel('Checkout verification disposed');
    _retryTimer?.cancel();
    chatRouteObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Column(
        children: [
          const Expanded(child: PageLoading('驗證物流資料中，請稍後……')),
          TextButton(
            onPressed: () => _leave(widget.onBack),
            child: const Text('返回購物車'),
          ),
          const SizedBox(height: 24),
        ],
      );
    }
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.info_outline,
              color: AppColors.goldColor,
              size: 36,
            ),
            const SizedBox(height: 16),
            Text(
              _error ?? '無法完成物流驗證',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.primaryTextColor),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _retrySeconds > 0 || _accountChanged ? null : _verify,
              child: Text(_retrySeconds > 0 ? '重試（$_retrySeconds 秒）' : '重試'),
            ),
            if (!_accountChanged)
              TextButton(
                onPressed: () => _leave(widget.onEdit),
                child: const Text('修改寄貨資料'),
              ),
            TextButton(
              onPressed: () => _leave(widget.onBack),
              child: const Text('返回購物車'),
            ),
          ],
        ),
      ),
    );
  }
}
