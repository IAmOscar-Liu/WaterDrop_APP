import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_ad_ecommerce/utils/app_failure.dart';
import 'page_status.dart';

/// Read-only document views can be recreated on an explicit retry.
class RecoverableWebView extends StatefulWidget {
  const RecoverableWebView({
    super.key,
    required this.onCreated,
    this.onPermissionRequest,
  });
  final Future<void> Function(InAppWebViewController) onCreated;
  final Future<PermissionResponse?> Function(
    InAppWebViewController,
    PermissionRequest,
  )?
  onPermissionRequest;
  @override
  State<RecoverableWebView> createState() => _RecoverableWebViewState();
}

class _RecoverableWebViewState extends State<RecoverableWebView> {
  AppFailure? _failure;
  int _generation = 0;
  void _fail(AppFailure failure) {
    if (mounted) setState(() => _failure = failure);
  }

  @override
  Widget build(BuildContext context) {
    if (_failure != null) {
      return PageError(
        _failure,
        onRetry: () => setState(() {
          _failure = null;
          _generation++;
        }),
      );
    }
    return InAppWebView(
      key: ValueKey(_generation),
      onPermissionRequest: widget.onPermissionRequest,
      onWebViewCreated: (controller) async {
        try {
          await widget.onCreated(controller);
        } catch (_) {
          _fail(const AppFailure(kind: FailureKind.connection));
        }
      },
      onReceivedError: (_, request, error) {
        if (request.isForMainFrame == true) {
          _fail(const AppFailure(kind: FailureKind.connection));
        }
      },
      onReceivedHttpError: (_, request, response) {
        if (request.isForMainFrame == true) {
          _fail(AppFailure.from({'statusCode': response.statusCode}));
        }
      },
    );
  }
}
