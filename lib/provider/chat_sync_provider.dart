import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_ad_ecommerce/constants/app_constants.dart';
import 'package:flutter_ad_ecommerce/models/api_enums.dart';
import 'package:flutter_ad_ecommerce/models/chatroom.dart';
import 'package:flutter_ad_ecommerce/models/chatroom_list.dart';
import 'package:flutter_ad_ecommerce/provider/dio_provider.dart';
import 'package:flutter_ad_ecommerce/service/chatroom_sse_service.dart';
import 'package:flutter_ad_ecommerce/utils/custom_async_value.dart';
import 'package:flutter_ad_ecommerce/utils/file_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

final chatSyncProvider = ChangeNotifierProvider<ChatSyncController>((ref) {
  return ChatSyncController(
    ref.watch(dioProvider),
    ref.read(chatTokenRefreshProvider),
  );
});

class ChatDraft {
  ChatDraft(this.content, this.files) : id = const Uuid().v4();
  final String id;
  final String content;
  final List<XFile> files;
  final DateTime createdAt = DateTime.now();
  List<Map<String, dynamic>>? attachments;
  bool sending = false;
  String? error;
  bool confirmed = false;
  bool retryable = true;
  CancelToken? request;
}

class ChatHistory {
  final Map<String, ChatMessage> messages = {};
  final Map<String, int> readVersions = {};
  bool loading = false;
  bool loaded = false;
  bool loadingOlder = false;
  bool hasMore = false;
  bool removed = false;
  String? nextCursor;
  String? error;
  String? olderError;
  CancelToken? request;
  int generation = 0;

  List<ChatMessage> get sorted => messages.values.toList()
    ..sort((a, b) {
      final time = b.createdAt.compareTo(a.createdAt);
      return time != 0 ? time : b.id.compareTo(a.id);
    });

  void merge(ChatMessage message) {
    final old = messages[message.id];
    if (old != null && old.version > message.version) return;
    final patch = readVersions[message.id];
    messages[message.id] = patch != null && patch > message.version
        ? message.copyWith(isRead: true, version: patch)
        : message;
  }

  void read(String id, int version, {bool retain = false}) {
    final old = messages[id];
    if (old != null && version > old.version) {
      messages[id] = old.copyWith(isRead: true, version: version);
    }
    // Buffer only while a REST snapshot could still return an older version.
    if (loading || loadingOlder || retain) {
      if (version > (readVersions[id] ?? 0)) readVersions[id] = version;
    }
  }
}

/// Shared session state. REST completions are guarded by session and snapshot
/// generations; streams route synchronously before their checkpoint advances.
class ChatSyncController extends ChangeNotifier {
  ChatSyncController(this.dio, Future<bool> Function() refreshToken) {
    stream = ChatroomSseService(
      dio: dio,
      refreshToken: refreshToken,
      onReady: _ready,
      onEvent: applyEvent,
      onReset: _resetCaches,
      onStatus: (value) {
        connectionStatus = value;
        _notify();
      },
    );
  }
  final Dio dio;
  late final ChatroomSseService stream;
  final Map<String, ChatHistory> histories = {};
  final Map<String, List<ChatDraft>> drafts = {};
  final Map<String, Chatroom> _rooms = {};
  final Map<String, int> _removed = {};
  final Map<String, int> _opened = {};
  final Set<String> _reading = {};
  final Set<String> _readAgain = {};
  String? _user;
  bool _foreground = false;
  bool _disposed = false;
  int _session = 0;
  String connectionStatus = 'connecting';
  String? visibleRoom;
  Object? visibleOwner;
  bool get isDisposed => _disposed;
  int listVersion = 0;
  int totalUnread = 0;
  int totalRooms = 0;
  int _listGeneration = 0;
  int _page = 0;
  int _totalPages = 0;
  String? _listSnapshot;
  DateTime? _snapshotExpires;
  CancelToken? _listRequest;
  bool _listLoading = false;
  bool _listLoaded = false;
  bool _listMetadataDirty = false;
  bool _refreshingListMetadata = false;
  int _listMetadataPages = 0;
  String? listError;

  bool get connected => stream.ready && connectionStatus == 'connected';
  bool get hasMoreRooms => _page < _totalPages;
  List<Chatroom> get rooms =>
      _rooms.values.where((room) => room.listVisible).toList()..sort((a, b) {
        final at =
            a.lastActivityAt ??
            a.lastMessage?.createdAt ??
            a.createdAt ??
            DateTime(1970);
        final bt =
            b.lastActivityAt ??
            b.lastMessage?.createdAt ??
            b.createdAt ??
            DateTime(1970);
        final time = bt.compareTo(at);
        return time != 0 ? time : b.id.compareTo(a.id);
      });

  CustomAsyncValue<ChatRoomPagination> get listValue {
    if (!_listLoaded) {
      if (connectionStatus == 'unauthorized' ||
          connectionStatus == 'unavailable') {
        return CustomAsyncValue.error('聊天室連線不可用，請重新登入或稍後再試');
      }
      if (listError != null) return CustomAsyncValue.error(listError);
      return CustomAsyncValue.loading();
    }
    final value = ChatRoomPagination(
      rooms: rooms,
      total: totalRooms,
      page: _page,
      limit: AppConstants.paginationPageSize,
      totalPages: _totalPages,
    );
    return _listLoading
        ? CustomAsyncValue.fetching(value)
        : CustomAsyncValue.done(value);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void configureSession(String? user, {required bool foreground}) {
    if (_disposed) return;
    if (user != _user) {
      stream.stop(clearCursor: true);
      _session++;
      _user = user;
      _opened.clear();
      visibleRoom = null;
      visibleOwner = null;
      for (final pending in drafts.values) {
        for (final draft in pending) {
          draft.request?.cancel();
        }
      }
      drafts.clear();
      _clearCaches();
    }
    _foreground = foreground;
    if (user == null || !foreground) {
      stream.stop();
      connectionStatus = 'offline';
    } else {
      stream.start();
    }
    _notify();
  }

  void _clearCaches() {
    _listRequest?.cancel();
    ++_listGeneration;
    for (final history in histories.values) {
      history.request?.cancel();
    }
    histories.clear();
    _rooms.clear();
    _removed.clear();
    _reading.clear();
    _readAgain.clear();
    _listLoaded = false;
    _listLoading = false;
    _listMetadataDirty = false;
    _refreshingListMetadata = false;
    _listMetadataPages = 0;
    listError = null;
    _listSnapshot = null;
    _snapshotExpires = null;
    _page = 0;
    _totalPages = 0;
    listVersion = 0;
    totalUnread = 0;
    totalRooms = 0;
  }

  void _resetCaches() {
    _clearCaches();
    _notify();
  }

  void _ready(bool fresh) {
    if (_listMetadataDirty) {
      unawaited(refreshListMetadata());
    } else if (fresh || !_listLoaded) {
      unawaited(loadList());
    }
    for (final id in _opened.keys.toList()) {
      final history = histories.putIfAbsent(id, ChatHistory.new);
      if (!history.loaded && !history.loading && !history.removed) {
        unawaited(loadHistory(id));
      }
    }
    if (visibleRoom != null) unawaited(markRead(visibleRoom!));
  }

  void _listState(dynamic raw) {
    final data = Map<String, dynamic>.from(raw as Map);
    final version = data['version'] as int;
    if (version < listVersion) return;
    listVersion = version;
    totalRooms = data['totalRooms'] as int;
    totalUnread = data['totalUnread'] as int;
  }

  void _upsertRoom(Chatroom room, {bool rest = false}) {
    if ((_removed[room.id] ?? -1) >= room.version) return;
    final old = _rooms[room.id];
    // REST may refresh product/order metadata without a chat revision bump.
    if (old == null ||
        room.version > old.version ||
        (rest && room.version == old.version)) {
      _rooms[room.id] = room;
    }
    if (room.version > (_removed[room.id] ?? -1)) _removed.remove(room.id);
  }

  void applyEvent(String type, Map<String, dynamic> data) {
    final id = data['chatRoomId'];
    if (id is! String || id.isEmpty) {
      throw const FormatException('Missing chatRoomId');
    }
    switch (type) {
      case 'message.created':
        final message = ChatMessage.fromApiResponseMap(
          Map<String, dynamic>.from(data['message'] as Map),
        );
        if (message.chatRoomId != id ||
            message.id.isEmpty ||
            message.version < 1) {
          throw const FormatException('Invalid message');
        }
        if (!(_removed.containsKey(id))) {
          histories[id]?.merge(message);
          _confirmDraft(id, message);
          if (_foreground &&
              visibleRoom == id &&
              message.senderType != ChatMessageSenderType.user) {
            unawaited(markRead(id));
          }
        }
      case 'messages.read':
        final history = histories[id];
        for (final patch in data['messages'] as List) {
          final messageId = patch['id'] as String;
          final version = patch['version'] as int;
          if (patch['isRead'] != true || version < 1) {
            throw const FormatException('Invalid read patch');
          }
          history?.read(
            messageId,
            version,
            retain: drafts[id]?.isNotEmpty ?? false,
          );
        }
      case 'chatroom.updated':
        final room = Chatroom.fromApiResponseMap(
          Map<String, dynamic>.from(data['room'] as Map),
        );
        if (room.id != id || room.version < 1) {
          throw const FormatException('Invalid room');
        }
        _upsertRoom(room);
        _listState(data['listState']);
        if (histories[id]?.removed == true && !_removed.containsKey(id)) {
          histories.remove(id);
          if (_opened.containsKey(id)) unawaited(loadHistory(id));
        }
      case 'chatroom.removed':
        final version = data['roomVersion'] as int;
        if (version >= (_rooms[id]?.version ?? 0) &&
            version > (_removed[id] ?? 0)) {
          _removed[id] = version;
          _rooms.remove(id);
          histories[id]?.request?.cancel();
          histories[id] = ChatHistory()..removed = true;
          for (final draft in drafts.remove(id) ?? <ChatDraft>[]) {
            draft.request?.cancel();
          }
        }
        _listState(data['listState']);
      default:
        throw FormatException('Unsupported chat event: $type');
    }
    // A full bootstrap is safer than dropping an override needed by a snapshot.
    if (_rooms.length + _removed.length > 12000 ||
        histories.values.any((h) => h.readVersions.length > 20000)) {
      throw const FormatException('Chat event buffer limit');
    }
    _notify();
  }

  /// Order/delivery metadata changes independently of the chat SSE revision.
  /// Re-read loaded pages, retaining rows and the snapshot for stable scrolling.
  Future<void> refreshListMetadata() async {
    if (_disposed || _user == null) return;
    _listMetadataDirty = true;
    if (_page > _listMetadataPages) _listMetadataPages = _page;
    if (!stream.ready || _listLoading || _refreshingListMetadata) return;
    final session = _session;
    _refreshingListMetadata = true;
    try {
      do {
        _listMetadataDirty = false;
        final loadedPages = _listMetadataPages;
        await _loadList(metadataRefresh: true);
        while (_valid(session) &&
            stream.ready &&
            listError == null &&
            hasMoreRooms &&
            _page < loadedPages) {
          await _loadList(more: true, metadataRefresh: true);
        }
      } while (_valid(session) &&
          stream.ready &&
          _listMetadataDirty &&
          listError == null);
    } finally {
      if (_valid(session)) {
        _refreshingListMetadata = false;
        if (!stream.ready || listError != null) {
          _listMetadataDirty = true;
        } else if (!_listMetadataDirty) {
          _listMetadataPages = 0;
        }
      }
    }
  }

  Future<void> loadList({bool more = false}) => _loadList(more: more);

  Future<void> _loadList({
    bool more = false,
    bool metadataRefresh = false,
  }) async {
    if (_refreshingListMetadata && !metadataRefresh) return;
    if (!stream.ready || _user == null || _listLoading) return;
    if (more && !hasMoreRooms) return;
    // Reuse the frozen token on page-one refreshes; BE caps active snapshots.
    if (_snapshotExpires?.isBefore(DateTime.now()) ?? false) {
      _listSnapshot = null;
    }
    final snapshot = _listSnapshot;
    final page = more && _listSnapshot != null ? _page + 1 : 1;
    final gen = ++_listGeneration;
    final session = _session;
    _listRequest?.cancel();
    final cancel = _listRequest = CancelToken();
    if (_listSnapshot == null) {
      _page = 0;
      _totalPages = 0;
    }
    _listLoading = true;
    listError = null;
    _notify();
    try {
      final response = await dio.get(
        '/api/chatroom/sync/list',
        cancelToken: cancel,
        queryParameters: {
          'page': page,
          'limit': AppConstants.paginationPageSize,
          if (_listSnapshot == null)
            'snapshot': true
          else
            'listSnapshot': _listSnapshot,
        },
      );
      if (!_valid(session) || gen != _listGeneration) return;
      final data = _data(response);
      _listSnapshot = data['listSnapshot'] as String;
      _snapshotExpires = DateTime.tryParse(
        data['listSnapshotExpiresAt'] as String? ?? '',
      );
      for (final raw in data['rooms'] as List) {
        _upsertRoom(
          Chatroom.fromApiResponseMap(Map<String, dynamic>.from(raw)),
          rest: true,
        );
      }
      _listState(data['listState']);
      _page = page;
      _totalPages = data['totalPages'] as int;
      _listLoaded = true;
    } catch (error) {
      if (!_valid(session) || gen != _listGeneration) return;
      final code = _code(error);
      if (snapshot != null &&
          (code == 'CHATROOM_LIST_SNAPSHOT_EXPIRED' ||
              code == 'CHATROOM_LIST_SNAPSHOT_INVALID')) {
        _listSnapshot = null;
        _listLoading = false;
        return _loadList(metadataRefresh: metadataRefresh);
      }
      listError = _error(error);
    } finally {
      if (_valid(session) && gen == _listGeneration) {
        _listLoading = false;
        _notify();
        if (_listMetadataDirty && !_refreshingListMetadata && stream.ready) {
          unawaited(refreshListMetadata());
        }
      }
    }
  }

  void openRoom(String id) {
    _opened[id] = (_opened[id] ?? 0) + 1;
    if (_removed.containsKey(id)) {
      histories[id] = ChatHistory()..removed = true;
      _notify();
      return;
    }
    histories.putIfAbsent(id, ChatHistory.new);
    unawaited(loadHistory(id));
  }

  void closeRoom(String id) {
    if ((_opened[id] ?? 0) > 1) {
      _opened[id] = _opened[id]! - 1;
      return;
    }
    _opened.remove(id);
    // Keep bounded caches only for mounted rooms. Drafts survive room navigation.
    histories.remove(id)?.request?.cancel();
  }

  void setVisibleRoom(String? id, {Object? owner}) {
    if (id == null && owner != null && !identical(visibleOwner, owner)) return;
    visibleRoom = id;
    visibleOwner = id == null ? null : owner;
    if (id != null && _foreground) unawaited(markRead(id));
  }

  Future<void> loadHistory(String id, {bool older = false}) async {
    final history = histories.putIfAbsent(id, ChatHistory.new);
    if (!stream.ready ||
        history.removed ||
        history.loading ||
        history.loadingOlder) {
      return;
    }
    if (older && (!history.hasMore || history.nextCursor == null)) return;
    final session = _session;
    final gen = ++history.generation;
    final cancel = history.request = CancelToken();
    if (older) {
      history.loadingOlder = true;
      history.olderError = null;
    } else {
      history.loading = true;
      history.error = null;
      history.messages.clear();
    }
    _notify();
    try {
      final response = await dio.get(
        '/api/chatroom/sync/history/$id',
        cancelToken: cancel,
        queryParameters: {
          'limit': AppConstants.paginationPageSize,
          if (older) 'before': history.nextCursor else 'page': 1,
        },
      );
      if (!_historyValid(id, history, session, gen)) return;
      final data = _data(response);
      for (final raw in data['messages'] as List) {
        final message = ChatMessage.fromApiResponseMap(
          Map<String, dynamic>.from(raw),
        );
        if (message.chatRoomId != id) {
          throw const FormatException('History room mismatch');
        }
        history.merge(message);
        _confirmDraft(id, message);
      }
      history.hasMore = data['hasMore'] == true;
      history.nextCursor = data['nextCursor'] as String?;
      history.loaded = true;
      if (visibleRoom == id) unawaited(markRead(id));
    } catch (error) {
      if (!_historyValid(id, history, session, gen)) return;
      if (_code(error) == 'CHAT_HISTORY_CURSOR_INVALID' && older) {
        history.loadingOlder = false;
        history.nextCursor = null;
        return loadHistory(id);
      }
      if (error is DioException &&
          [403, 404].contains(error.response?.statusCode)) {
        history.removed = true;
      }
      if (older) {
        history.olderError = _error(error);
      } else {
        history.error = _error(error);
      }
    } finally {
      if (_historyValid(id, history, session, gen)) {
        history.loading = false;
        history.loadingOlder = false;
        if (drafts[id]?.isEmpty ?? true) history.readVersions.clear();
        _notify();
      }
    }
  }

  bool _valid(int session) =>
      !_disposed && _user != null && session == _session;
  bool _historyValid(String id, ChatHistory h, int session, int gen) =>
      _valid(session) && identical(histories[id], h) && h.generation == gen;

  Future<void> markRead(String id) async {
    if (!_foreground ||
        visibleRoom != id ||
        histories[id]?.loaded != true ||
        histories[id]?.removed == true) {
      return;
    }
    if (_reading.contains(id)) {
      _readAgain.add(id);
      return;
    }
    _reading.add(id);
    final session = _session;
    try {
      final response = await dio.put(
        '/api/chatroom/sync/message/$id/read',
        data: {'readerType': 'user'},
      );
      if (!_valid(session)) return;
      // The authoritative stream also delivers these patches; tolerate either
      // documented changed-message envelope while keeping SSE as the fallback.
      final body = response.data['data'];
      final patches = body is List
          ? body
          : body is Map
          ? body['messages']
          : null;
      if (patches is List) {
        for (final patch in patches) {
          if (patch['id'] is String &&
              patch['version'] is int &&
              patch['isRead'] == true) {
            histories[id]?.read(
              patch['id'],
              patch['version'],
              retain: drafts[id]?.isNotEmpty ?? false,
            );
          }
        }
        _notify();
      }
    } catch (_) {
      /* Re-entry/reconnect or the next incoming message retries. */
    } finally {
      if (_valid(session)) {
        _reading.remove(id);
        if (_readAgain.remove(id)) unawaited(markRead(id));
      }
    }
  }

  void _confirmDraft(String id, ChatMessage message) {
    final pending = drafts[id];
    if (pending == null) return;
    for (final draft in pending) {
      if (draft.id == message.clientMessageId) draft.confirmed = true;
    }
    pending.removeWhere((draft) => draft.confirmed);
  }

  Future<void> send(String id, String content, List<XFile> files) async {
    final draft = ChatDraft(content, List.of(files));
    drafts.putIfAbsent(id, () => []).add(draft);
    await retrySend(id, draft);
  }

  Future<void> retrySend(String id, ChatDraft draft) async {
    if (!draft.retryable ||
        draft.sending ||
        _user == null ||
        histories[id]?.removed == true) {
      return;
    }
    final session = _session;
    final cancel = draft.request = CancelToken();
    draft.sending = true;
    draft.error = null;
    _notify();
    try {
      if (draft.attachments == null) {
        final uploads = <Map<String, dynamic>>[];
        for (final file in draft.files) {
          final endpoint = isXFileImage(file)
              ? '/api/file/image/upload'
              : isXFileVideo(file)
              ? '/api/file/video/upload'
              : null;
          if (endpoint == null) throw Exception('不支援的附件格式');
          final response = await dio.post(
            endpoint,
            cancelToken: cancel,
            data: FormData.fromMap({
              'file': await MultipartFile.fromFile(
                file.path,
                filename: file.name,
              ),
              'path': 'chat/$id',
            }),
          );
          if (!_valid(session) || histories[id]?.removed == true) return;
          if (response.data['success'] != true) throw Exception('附件上傳失敗');
          uploads.add({
            'url': response.data['data'],
            'mimeType': getXFileMimeType(file),
            'name': file.name,
            'size': await file.length(),
          });
        }
        draft.attachments = uploads;
      }
      if (!_valid(session) || histories[id]?.removed == true) return;
      final response = await dio.post(
        '/api/chatroom/sync/message/$id',
        cancelToken: cancel,
        data: {
          'senderType': 'user',
          'content': draft.content.isEmpty ? null : draft.content,
          'attachments': draft.attachments,
          'clientMessageId': draft.id,
        },
      );
      if (!_valid(session) || histories[id]?.removed == true) return;
      final message = ChatMessage.fromApiResponseMap(_data(response));
      if (message.chatRoomId != id || message.clientMessageId != draft.id) {
        throw const FormatException('Invalid send confirmation');
      }
      histories[id]?.merge(message);
      _confirmDraft(id, message);
    } catch (error) {
      if (_valid(session) && !draft.confirmed) {
        draft.retryable = _code(error) != 'CLIENT_MESSAGE_ID_CONFLICT';
        draft.error = draft.retryable ? _error(error) : '訊息內容衝突，請重新撰寫';
      }
    } finally {
      if (_valid(session)) {
        draft.sending = false;
        _notify();
      }
    }
  }

  Map<String, dynamic> _data(Response response) {
    if (response.data is! Map ||
        response.data['success'] != true ||
        response.data['data'] is! Map) {
      throw const FormatException('Invalid chat response');
    }
    return Map<String, dynamic>.from(response.data['data']);
  }

  String? _code(Object error) =>
      error is DioException && error.response?.data is Map
      ? error.response!.data['code'] as String?
      : null;
  String _error(Object error) =>
      error is DioException && error.response?.data is Map
      ? (error.response!.data['message'] ?? '連線失敗，請重試').toString()
      : '載入或傳送失敗，請重試';

  @override
  void dispose() {
    _disposed = true;
    for (final pending in drafts.values) {
      for (final draft in pending) {
        draft.request?.cancel();
      }
    }
    stream.stop(clearCursor: true);
    _clearCaches();
    super.dispose();
  }
}
