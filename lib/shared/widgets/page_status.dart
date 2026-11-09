import 'dart:async';
import 'package:flutter_ad_ecommerce/constants/colors.dart';
import 'package:flutter_ad_ecommerce/utils/app_failure.dart';
import 'package:flutter/material.dart';

class PageLoading extends StatelessWidget {
  const PageLoading(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(text, style: TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}

class PageError extends StatelessWidget {
  const PageError(this.error, {super.key, this.onRetry, this.message});
  final Object? error;
  final VoidCallback? onRetry;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final failure = AppFailure.from(error);
    if (failure.canceled) return const SizedBox.shrink();
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              failure.kind == FailureKind.connection
                  ? Icons.wifi_off_rounded
                  : Icons.error_outline_rounded,
              color: AppColors.secondaryTextColor,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              failure.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.primaryTextColor,
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message ?? failure.message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.secondaryTextColor,
                height: 1.5,
              ),
            ),
            if (failure.requestId != null) ...[
              const SizedBox(height: 12),
              Text(
                '參考編號：${failure.requestId}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.mutedTextColor,
                  fontSize: 11,
                ),
              ),
            ],
            if (onRetry != null && failure.canRetry) ...[
              const SizedBox(height: 20),
              ErrorRetryButton(onRetry: onRetry!, retryAt: failure.retryAt),
            ],
            if (!failure.canRetry && Navigator.of(context).canPop())
              TextButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('返回'),
              ),
          ],
        ),
      ),
    );
  }
}

class ErrorRetryButton extends StatefulWidget {
  const ErrorRetryButton({
    super.key,
    required this.onRetry,
    this.retryAt,
    this.label = '重試',
  });
  final VoidCallback onRetry;
  final DateTime? retryAt;
  final String label;
  @override
  State<ErrorRetryButton> createState() => _ErrorRetryButtonState();
}

class _ErrorRetryButtonState extends State<ErrorRetryButton> {
  Timer? _timer;
  bool _retrying = false;
  int get _seconds => widget.retryAt == null
      ? 0
      : (widget.retryAt!.difference(DateTime.now()).inMilliseconds / 1000)
            .ceil()
            .clamp(0, 2147483647);
  void _schedule() {
    _timer?.cancel();
    if (_seconds > 0) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
        if (_seconds == 0) _timer?.cancel();
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(covariant ErrorRetryButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _retrying = false;
    _schedule();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: _seconds > 0 || _retrying
        ? null
        : () {
            setState(() => _retrying = true);
            widget.onRetry();
          },
    style: TextButton.styleFrom(
      foregroundColor: AppColors.infoColor,
      disabledForegroundColor: AppColors.mutedTextColor,
    ),
    icon: const Icon(Icons.refresh, size: 18),
    label: Text(_seconds > 0 ? '${_seconds.toString()}秒後重試' : widget.label),
  );
}

class DataRefreshNotice extends StatelessWidget {
  const DataRefreshNotice({
    super.key,
    required this.error,
    required this.onRetry,
  });
  final Object? error;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    child: Row(
      children: [
        const Icon(
          Icons.cloud_off_outlined,
          size: 18,
          color: AppColors.warningColor,
        ),
        const SizedBox(width: 8),
        const Expanded(
          child: Text(
            '暫時無法更新，正顯示先前載入的資料。',
            style: TextStyle(color: AppColors.secondaryTextColor),
          ),
        ),
        ErrorRetryButton(
          onRetry: onRetry,
          retryAt: AppFailure.from(error).retryAt,
        ),
      ],
    ),
  );
}

/// Empty list content. The caller supplies any outer centering or scrolling.
class EmptyState extends StatelessWidget {
  const EmptyState(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.sentiment_dissatisfied, size: 48, color: Colors.white),
        const SizedBox(height: 12),
        Text(text, style: const TextStyle(color: Colors.white)),
      ],
    );
  }
}
