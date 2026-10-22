import 'dart:async';
import 'dart:developer';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_ad_ecommerce/models/app_badge.dart';
import 'package:flutter_ad_ecommerce/provider/dio_provider.dart';
import 'package:flutter_ad_ecommerce/service/app_badge_service.dart';

final appBadgeProvider = ChangeNotifierProvider<AppBadgeController>((ref) {
  final service = AppBadgeService();
  return AppBadgeController(
    ref.watch(dioProvider),
    service.setCount,
    clearSession: service.clearSession,
  );
});

class AppBadgeController extends ChangeNotifier {
  AppBadgeController(
    this.dio,
    this.writeBadge, {
    DateTime Function()? now,
    this.clearSession,
  }) : now = now ?? DateTime.now;
  final Dio dio;
  final Future<void> Function(int) writeBadge;
  final Future<void> Function()? clearSession;
  final DateTime Function() now;
  AppBadge? snapshot;
  String? userId;
  bool _foreground = false, _configured = false, _disposed = false;
  bool _dirty = false;
  int _epoch = 0;
  CancelToken? _request;
  Timer? _debounce, _deadline;
  Future<void> _writes = Future.value();
  String? error;

  void configureSession(String? user, {required bool foreground}) {
    if (_disposed) return;
    if (_configured && user == userId && foreground == _foreground) return;
    final previousUser = userId;
    final changedUser = !_configured || user != userId;
    _configured = true;
    _epoch++;
    _debounce?.cancel();
    _deadline?.cancel();
    _request?.cancel('Badge session changed');
    _request = null;
    _dirty = false;
    userId = user;
    _foreground = foreground;
    if (changedUser) {
      snapshot = null;
      error = null;
      // Do not clear a restored user's OS badge before REST succeeds. Clear on
      // logout/account switch; the host clears the old session before a new one.
      if (user == null || previousUser != null) _write(0, clear: true);
      notifyListeners();
    }
    if (user != null && foreground) invalidate();
  }

  void invalidate() {
    if (_disposed || userId == null) return;
    _dirty = true;
    if (!_foreground || _request != null || (_debounce?.isActive ?? false)) {
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 200), () {
      unawaited(_refresh());
    });
  }

  /// Push metadata is a hint, never a partial replacement for REST counts.
  bool handlePush(Map<String, dynamic> data) {
    if (userId == null || data['badgeUserId'] != userId) return false;
    final version = int.tryParse('${data['badgeVersion']}');
    final total = int.tryParse('${data['badgeTotal']}');
    if (version == null || version < 1 || total == null || total < 0) {
      return false;
    }
    if (version < (snapshot?.version ?? 0)) return false;
    invalidate();
    return true;
  }

  Future<void> _refresh() async {
    if (_disposed || !_foreground || userId == null || _request != null) return;
    final epoch = _epoch;
    final token = CancelToken();
    _request = token;
    _dirty = false;
    try {
      final response = await dio.get('/api/app/badge', cancelToken: token);
      if (!_valid(epoch)) return;
      if (response.data is! Map || response.data['success'] != true) {
        throw const FormatException('Invalid badge response');
      }
      final value = AppBadge.fromJson(response.data['data']);
      if (value.version < (snapshot?.version ?? 0)) return;
      snapshot = value; // Equal revisions can contain a newer deadline.
      error = null;
      _write(value.total);
      _scheduleDeadline(value.nextReconcileAt);
      notifyListeners();
    } catch (e) {
      if (_valid(epoch) && (e is! DioException || !CancelToken.isCancel(e))) {
        error = '無法更新未讀數量';
        log('App badge reconciliation failed: ${e.runtimeType}');
        notifyListeners();
      }
    } finally {
      if (_valid(epoch)) {
        _request = null;
        if (_dirty) invalidate();
      }
    }
  }

  bool _valid(int epoch) => !_disposed && epoch == _epoch;

  void _scheduleDeadline(DateTime? deadline) {
    _deadline?.cancel();
    if (deadline == null || !_foreground) return;
    final remaining = deadline.difference(now().toUtc());
    // Server/device skew or an already-due timestamp must not spin requests.
    final delay = remaining < const Duration(seconds: 30)
        ? const Duration(seconds: 30)
        : remaining;
    _deadline = Timer(delay, invalidate);
  }

  void _write(int count, {bool clear = false}) {
    final epoch = _epoch;
    _writes = _writes.then((_) async {
      if (_disposed || (!clear && (!_valid(epoch) || !_foreground))) return;
      try {
        if (clear && clearSession != null) {
          await clearSession!();
        } else {
          await writeBadge(count);
        }
      } catch (e) {
        log('Native badge update failed: ${e.runtimeType}');
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    _debounce?.cancel();
    _deadline?.cancel();
    _request?.cancel();
    super.dispose();
  }
}
