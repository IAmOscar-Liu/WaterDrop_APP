import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_ad_ecommerce/constants/app_constants.dart';
import 'package:flutter_ad_ecommerce/models/api_enums.dart';
import 'package:flutter_ad_ecommerce/models/message.dart';
import 'package:flutter_ad_ecommerce/provider/dio_provider.dart';
import 'package:flutter_ad_ecommerce/service/user_sse_service.dart';
import 'package:flutter_ad_ecommerce/utils/custom_async_value.dart';
import 'package:flutter_ad_ecommerce/utils/result.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final notificationSyncProvider =
    ChangeNotifierProvider<NotificationSyncController>((ref) {
      return NotificationSyncController(
        ref.watch(dioProvider),
        ref.read(chatTokenRefreshProvider),
      );
    });

/// Each mounted page owns its query, so stacked routes cannot overwrite filters.
class NotificationQuery {
  NotificationQuery({this.type, this.search = '', this.onlyUnread = false});
  final NotificationType? type;
  final String search;
  final bool onlyUnread;
  final ids = <String>{};
  final changesDuringLoad = <String>{};
  bool visible = false;
  bool nearTop = true;
  bool dirty = true;
  bool loaded = false;
  bool loading = false;
  bool retryMore = false;
  int generation = 0;
  int revision = 0;
  int page = 0;
  int total = 0;
  int totalPages = 0;
  String? snapshot;
  DateTime? expires;
  DateTime? retryAt;
  String? error;
  CancelToken? request;
  Timer? debounce;
  bool get hasMore => page < totalPages;
  bool matches(Message item) =>
      (type == null || type == item.type) && (!onlyUnread || !item.isRead);
}

class NotificationDetail {
  NotificationDetail(this.id);
  final String id;
  bool visible = false;
  bool loading = false;
  bool loaded = false;
  String? error;
  CancelToken? request;
}

class NotificationSyncController extends ChangeNotifier {
  NotificationSyncController(this.dio, Future<bool> Function() refreshToken) {
    stream = UserSseService(
      dio: dio,
      path: '/api/notification/events',
      cursorInvalidCode: 'NOTIFICATION_STREAM_CURSOR_INVALID',
      refreshToken: refreshToken,
      onReady: _ready,
      onEvent: applyEvent,
      onReset: _reset,
      onStatus: (status) {
        connectionStatus = status;
        _notify();
      },
    );
  }
  final Dio dio;
  late final UserSseService stream;
  final _items = <String, Message>{};
  final _deleted = <String, int>{};
  final _unavailable = <String>{};
  final _queries = <NotificationQuery>{};
  final _details = <NotificationDetail>{};
  final _mutations = <String, Future<Result<bool>>>{};
  final _requests = <CancelToken>{};
  String? _user;
  int _epoch = 0;
  bool _foreground = false;
  bool _disposed = false;
  bool _statsLoading = false;
  MessageStats? stats;
  String? statsError;
  String connectionStatus = 'offline';
  bool get connected => stream.ready && connectionStatus == 'connected';
  bool get messageCenterVisible =>
      _foreground && _queries.any((q) => q.visible);
  Message? item(String id) =>
      _unavailable.contains(id) || _deleted.containsKey(id) ? null : _items[id];
  bool unavailable(String id) =>
      _unavailable.contains(id) || _deleted.containsKey(id);
  bool deleting(String id) => _mutations.containsKey('delete:$id');

  CustomAsyncValue<MessageStats> get statsValue => stats != null
      ? CustomAsyncValue.done(stats!)
      : statsError != null
      ? CustomAsyncValue.error(statsError)
      : CustomAsyncValue.loading();

  List<Message> messages(NotificationQuery query) =>
      [
        for (final id in query.ids)
          if (item(id) case final Message value)
            if (query.matches(value)) value,
      ]..sort((a, b) {
        final date = b.createdAt.compareTo(a.createdAt);
        return date != 0 ? date : b.id.compareTo(a.id);
      });

  CustomAsyncValue<MessagePagination> listValue(NotificationQuery query) {
    if (!query.loaded) {
      if (query.error != null) return CustomAsyncValue.error(query.error);
      if (connectionStatus == 'unauthorized' ||
          connectionStatus == 'unavailable') {
        return CustomAsyncValue.error('訊息連線不可用，請重新登入或稍後再試');
      }
      return CustomAsyncValue.loading();
    }
    final result = MessagePagination(
      messages: messages(query),
      total: query.total,
      page: query.page,
      limit: AppConstants.paginationPageSize,
      totalPages: query.totalPages,
    );
    return query.loading
        ? CustomAsyncValue.fetching(result)
        : CustomAsyncValue.done(result);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  bool _valid(int epoch) => !_disposed && _user != null && epoch == _epoch;

  void configureSession(String? user, {required bool foreground}) {
    if (_disposed) return;
    if (_user != user) {
      stream.stop(clearCursor: true);
      _user = user;
      _reset();
    }
    _foreground = foreground;
    if (user != null && foreground) {
      stream.start();
    } else {
      stream.stop();
      connectionStatus = 'offline';
      for (final query in _queries) {
        query.debounce?.cancel();
      }
    }
    _notify();
  }

  void _reset() {
    _epoch++;
    for (final request in _requests) {
      request.cancel();
    }
    _requests.clear();
    _mutations.clear();
    _statsLoading = false;
    stats = null;
    statsError = null;
    _items.clear();
    _deleted.clear();
    _unavailable.clear();
    for (final q in _queries) {
      q.request?.cancel();
      q.debounce?.cancel();
      q.generation++;
      q.ids.clear();
      q.changesDuringLoad.clear();
      q.snapshot = null;
      q.expires = null;
      q.retryAt = null;
      q.page = q.totalPages = q.total = 0;
      q.loading = q.loaded = false;
      q.dirty = true;
      q.error = null;
    }
    for (final detail in _details) {
      detail.request?.cancel();
      detail.loading = detail.loaded = false;
      detail.error = null;
    }
    _notify();
  }

  void _ready(bool fresh) {
    if (fresh || stats == null) unawaited(loadStats());
    for (final q in _queries) {
      if (q.visible && (!q.loaded || q.dirty)) unawaited(loadList(q));
    }
    for (final d in _details) {
      if (d.visible) {
        if (!d.loaded) {
          unawaited(loadDetail(d));
        } else {
          _readVisible(d);
        }
      }
    }
  }

  NotificationQuery openQuery({
    NotificationType? type,
    String search = '',
    bool onlyUnread = false,
  }) {
    final q = NotificationQuery(
      type: type,
      search: search,
      onlyUnread: onlyUnread,
    );
    _queries.add(q);
    return q;
  }

  void closeQuery(NotificationQuery q) {
    q.request?.cancel();
    q.debounce?.cancel();
    q.generation++;
    _queries.remove(q);
    _trimUnused();
  }

  void setQueryVisible(NotificationQuery q, bool visible, {bool? nearTop}) {
    if (!_queries.contains(q)) return;
    final entering = visible && !q.visible;
    q.visible = visible;
    if (nearTop != null) q.nearTop = nearTop;
    if (visible && (entering || q.nearTop) && (!q.loaded || q.dirty)) {
      _schedule(q);
    }
  }

  void _schedule(NotificationQuery q) {
    q.debounce?.cancel();
    if (!_foreground || !q.visible || (q.loaded && !q.nearTop)) return;
    q.debounce = Timer(const Duration(milliseconds: 300), () {
      if (_queries.contains(q) && q.visible && q.dirty) unawaited(loadList(q));
    });
  }

  void _trimUnused() {
    if (_queries.isEmpty && _details.isEmpty && _mutations.isEmpty) {
      _items.clear();
      _deleted.clear();
      _unavailable.clear();
    }
  }

  Message _parseItem(dynamic raw) {
    final map = Map<String, dynamic>.from(raw as Map);
    final value = Message.fromApiResponseMap(map);
    if (value.id.isEmpty || value.userId != _user || value.version < 1) {
      throw const FormatException('Invalid notification');
    }
    return value;
  }

  MessageStats _parseStats(dynamic raw) {
    final map = Map<String, dynamic>.from(raw as Map);
    for (final key in [
      'version',
      'total',
      'system_alert',
      'order_status',
      'promotion',
      'coins_earned',
      'chat_message',
      'other',
    ]) {
      if (map[key] is! int || (map[key] as int) < 0) {
        throw const FormatException('Invalid notification stats');
      }
    }
    final value = MessageStats.fromApiResponseMap(map);
    if (value.total !=
        value.systemAlert +
            value.orderStatus +
            value.promotion +
            value.coinsEarned +
            value.chatMessage +
            value.other) {
      throw const FormatException('Invalid unread total');
    }
    return value;
  }

  void _mergeStats(MessageStats value) {
    if (stats == null || value.version >= stats!.version) {
      stats = value;
      statsError = null;
    }
  }

  bool _upsert(Message value) {
    if (_unavailable.contains(value.id) ||
        (_deleted[value.id] ?? -1) >= value.version ||
        (_items[value.id]?.version ?? -1) >= value.version) {
      return false;
    }
    _items[value.id] = value;
    return true;
  }

  void _remove(String id, int version) {
    if (version < (_items[id]?.version ?? 0) ||
        version <= (_deleted[id] ?? 0)) {
      return;
    }
    _deleted[id] = version;
    _items.remove(id);
    for (final q in _queries) {
      q.ids.remove(id);
    }
  }

  void _changed(String id) {
    for (final q in _queries) {
      q.revision++;
      if (q.loading) q.changesDuringLoad.add(id);
      final value = item(id);
      if (value == null || !q.matches(value)) {
        q.ids.remove(id);
      } else if (q.search.isEmpty) {
        q.ids.add(id);
      }
      if (q.search.isNotEmpty) {
        q.dirty = true;
        _schedule(q);
      }
    }
    for (final detail in _details.where((d) => d.id == id)) {
      _readVisible(detail);
    }
  }

  void applyEvent(String type, Map<String, dynamic> data) {
    final counts = _parseStats(data['stats']);
    if (type == 'notification.created' || type == 'notification.updated') {
      final value = _parseItem(data['notification']);
      // Keep unopened lists invalidated by construction, without storing the feed.
      if (_queries.isNotEmpty || _details.isNotEmpty || _mutations.isNotEmpty) {
        if (_upsert(value)) _changed(value.id);
      }
    } else if (type == 'notification.deleted') {
      final id = data['notificationId'];
      final version = data['version'];
      if (id is! String || id.isEmpty || version is! int || version < 1) {
        throw const FormatException('Invalid notification deletion');
      }
      if (_queries.isNotEmpty || _details.isNotEmpty || _mutations.isNotEmpty) {
        _remove(id, version);
        _changed(id);
      }
    } else {
      throw FormatException('Unsupported notification event: $type');
    }
    _mergeStats(counts);
    if (_items.length + _deleted.length > 12000) {
      // Transport performs a full resync; never drop overrides silently.
      throw const FormatException('Notification cache limit');
    }
    _notify();
  }

  Map<String, dynamic> _data(Response response) {
    if (response.data is! Map ||
        response.data['success'] != true ||
        response.data['data'] is! Map) {
      throw const FormatException('Invalid notification response');
    }
    return Map<String, dynamic>.from(response.data['data']);
  }

  Future<void> loadStats() async {
    if (!stream.ready || _statsLoading || _user == null) return;
    final epoch = _epoch;
    final cancel = CancelToken();
    _requests.add(cancel);
    _statsLoading = true;
    try {
      final response = await dio.get(
        '/api/notification/sync/stats',
        cancelToken: cancel,
      );
      if (_valid(epoch)) _mergeStats(_parseStats(_data(response)));
    } catch (e) {
      if (_valid(epoch)) statsError = _error(e);
    } finally {
      _requests.remove(cancel);
      if (_valid(epoch)) {
        _statsLoading = false;
        _notify();
      }
    }
  }

  Future<void> loadList(NotificationQuery q, {bool more = false}) async {
    if (!stream.ready ||
        _user == null ||
        !_queries.contains(q) ||
        q.loading ||
        (more && !q.hasMore) ||
        (q.retryAt?.isAfter(DateTime.now()) ?? false)) {
      return;
    }
    final token = more && !(q.expires?.isBefore(DateTime.now()) ?? true)
        ? q.snapshot
        : null;
    final page = token == null ? 1 : q.page + 1;
    final epoch = _epoch;
    final generation = ++q.generation;
    final revision = q.revision;
    bool valid() =>
        _valid(epoch) && _queries.contains(q) && q.generation == generation;
    q.loading = true;
    q.error = null;
    q.retryMore = more;
    q.changesDuringLoad.clear();
    q.request?.cancel();
    final cancel = q.request = CancelToken();
    _notify();
    try {
      final response = await dio.get(
        '/api/notification/sync/list',
        cancelToken: cancel,
        queryParameters: {
          'page': page,
          'limit': AppConstants.paginationPageSize,
          'onlyUnread': q.onlyUnread,
          if (q.type != null) 'types': q.type!.wireValue,
          if (q.search.isNotEmpty) 'search': q.search,
          if (token == null) 'snapshot': true else 'listSnapshot': token,
        },
      );
      if (!valid()) return;
      final data = _data(response);
      final values = (data['notifications'] as List).map(_parseItem).toList();
      final counts = _parseStats(data['stats']);
      final ids = <String>{...q.changesDuringLoad};
      for (final value in values) {
        _upsert(value);
        ids.add(value.id);
      }
      if (page == 1) q.ids.clear();
      for (final id in ids) {
        final value = item(id);
        if (value != null && q.matches(value)) {
          // Search membership comes from REST, not a Dart approximation of ILIKE.
          if (q.search.isEmpty || values.any((v) => v.id == id)) q.ids.add(id);
        }
      }
      q.snapshot = data['listSnapshot'] as String;
      q.expires = DateTime.parse(data['listSnapshotExpiresAt'] as String);
      q.page = page;
      q.total = data['total'] as int;
      q.totalPages = data['totalPages'] as int;
      q.loaded = true;
      q.dirty = q.search.isNotEmpty && revision != q.revision;
      _mergeStats(counts);
    } catch (e) {
      if (!valid()) return;
      final code = _code(e);
      if (token != null &&
          (code == 'NOTIFICATION_LIST_SNAPSHOT_EXPIRED' ||
              code == 'NOTIFICATION_LIST_SNAPSHOT_INVALID')) {
        q.snapshot = null;
        q.expires = null;
        q.loading = false;
        return loadList(q);
      }
      q.error = _error(e);
      if (e is DioException && e.response?.statusCode == 429) {
        q.retryAt = DateTime.now().add(
          Duration(
            seconds:
                int.tryParse(e.response?.headers.value('retry-after') ?? '') ??
                15,
          ),
        );
      }
    } finally {
      if (valid()) {
        q.loading = false;
        q.changesDuringLoad.clear();
        if (q.dirty && q.error == null) _schedule(q);
        _notify();
      }
    }
  }

  NotificationDetail openDetail(String id) {
    final d = NotificationDetail(id);
    _details.add(d);
    return d;
  }

  void closeDetail(NotificationDetail detail) {
    detail.request?.cancel();
    _details.remove(detail);
    _trimUnused();
  }

  void setDetailVisible(NotificationDetail detail, bool visible) {
    if (!_details.contains(detail)) return;
    detail.visible = visible;
    if (visible) {
      if (!detail.loaded) {
        unawaited(loadDetail(detail));
      } else {
        _readVisible(detail);
      }
    }
  }

  void _readVisible(NotificationDetail d) {
    if (_foreground && d.visible && d.loaded && item(d.id)?.isRead == false) {
      unawaited(markRead(d.id));
    }
  }

  Future<void> loadDetail(NotificationDetail d) async {
    if (!stream.ready || !_details.contains(d) || d.loading || _user == null) {
      return;
    }
    final epoch = _epoch;
    d.loading = true;
    d.error = null;
    final cancel = d.request = CancelToken();
    _notify();
    try {
      final response = await dio.get(
        '/api/notification/sync/${d.id}',
        cancelToken: cancel,
      );
      if (!_valid(epoch) || !_details.contains(d)) return;
      final value = _parseItem(_data(response));
      if (value.id != d.id) {
        throw const FormatException('Wrong notification detail');
      }
      _upsert(value);
      d.loaded = true;
      _readVisible(d);
    } catch (e) {
      if (_valid(epoch) && _details.contains(d)) {
        d.error = _error(e);
        if (e is DioException && e.response?.statusCode == 404) {
          _unavailable.add(d.id);
        }
      }
    } finally {
      if (_valid(epoch) && _details.contains(d)) {
        d.loading = false;
        _notify();
      }
    }
  }

  Future<Result<bool>> markRead(String id) => _mutate(id, delete: false);
  Future<Result<bool>> delete(String id) => _mutate(id, delete: true);

  Future<Result<bool>> _mutate(String id, {required bool delete}) {
    final key = '${delete ? 'delete' : 'read'}:$id';
    final existing = _mutations[key];
    if (existing != null) return existing;
    if (_user == null) return Future.value(Result.failure('請先登入'));
    // Schedule after registering the future so events cannot start duplicate reads.
    final epoch = _epoch;
    final future = Future<Result<bool>>.microtask(
      () => _performMutation(id, delete, epoch),
    );
    _mutations[key] = future;
    _notify();
    future.whenComplete(() {
      if (_valid(epoch)) {
        _mutations.remove(key);
        _trimUnused();
        _notify();
      }
    });
    return future;
  }

  Future<Result<bool>> _performMutation(
    String id,
    bool delete,
    int epoch,
  ) async {
    if (!_valid(epoch)) return Result.failure('登入狀態已變更');
    final cancel = CancelToken();
    _requests.add(cancel);
    try {
      final response = delete
          ? await dio.delete(
              '/api/notification/sync',
              data: {
                'notificationIds': [id],
              },
              cancelToken: cancel,
            )
          : await dio.post(
              '/api/notification/sync/mark-as-read',
              data: {
                'notificationIds': [id],
              },
              cancelToken: cancel,
            );
      if (!_valid(epoch)) return Result.failure('登入狀態已變更');
      final data = _data(response);
      final counts = _parseStats(data['stats']);
      if (delete) {
        for (final raw in data['deleted'] as List) {
          final deletedId = raw['id'] as String;
          final version = raw['version'] as int;
          if (deletedId != id || version < 1) {
            throw const FormatException('Invalid deletion response');
          }
          _remove(deletedId, version);
          _changed(deletedId);
        }
      } else {
        for (final raw in data['notifications'] as List) {
          final value = _parseItem(raw);
          if (value.id != id || !value.isRead) {
            throw const FormatException('Invalid read response');
          }
          if (_upsert(value)) _changed(value.id);
        }
        // A no-op read can mean another device already read OR deleted it.
        // Reconcile that item when our cache cannot distinguish the two.
        if ((data['notifications'] as List).isEmpty &&
            item(id)?.isRead != true &&
            !unavailable(id)) {
          try {
            final detail = await dio.get(
              '/api/notification/sync/$id',
              cancelToken: cancel,
            );
            if (!_valid(epoch)) return Result.failure('登入狀態已變更');
            final value = _parseItem(_data(detail));
            if (value.id != id) {
              throw const FormatException('Wrong notification detail');
            }
            if (_upsert(value)) _changed(id);
          } on DioException catch (error) {
            if (!_valid(epoch)) return Result.failure('登入狀態已變更');
            if (error.response?.statusCode != 404) rethrow;
            _unavailable.add(id);
            _changed(id);
          }
        }
      }
      _mergeStats(counts);
      _notify();
      return Result.success(true);
    } catch (e) {
      if (!_valid(epoch)) return Result.failure('登入狀態已變更');
      if (delete
          ? _deleted.containsKey(id)
          : item(id)?.isRead == true || unavailable(id)) {
        return Result.success(
          true,
        ); // A server event already confirmed the change.
      }
      if (e is DioException && e.response?.statusCode == 404) {
        _unavailable.add(id);
        _changed(id);
        _notify();
      }
      return Result.failure(_error(e));
    } finally {
      _requests.remove(cancel);
    }
  }

  String? _code(Object e) => e is DioException && e.response?.data is Map
      ? e.response!.data['code'] as String?
      : null;
  String _error(Object e) => e is DioException && e.response?.data is Map
      ? (e.response!.data['message'] ?? '連線失敗，請重試').toString()
      : '連線失敗，請重試';

  @override
  void dispose() {
    _disposed = true;
    stream.stop(clearCursor: true);
    _reset();
    super.dispose();
  }
}
