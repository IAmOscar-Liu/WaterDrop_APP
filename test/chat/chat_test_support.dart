import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';

Map<String, dynamic> message(
  String id, {
  String room = 'a',
  int version = 1,
  bool read = false,
  String? clientId,
}) => {
  'id': id,
  'chatRoomId': room,
  'version': version,
  'isRead': read,
  'clientMessageId': clientId,
  'senderType': 'seller',
  'content': '你好 $id',
  'attachments': [],
  'createdAt': '2026-10-11T01:00:00.000Z',
};
Map<String, dynamic> room(
  String id, {
  int version = 1,
  bool visible = true,
  int unread = 1,
}) => {
  'id': id,
  'userId': 'u',
  'version': version,
  'listVisible': visible,
  'totalUnread': unread,
  'status': 'active',
  'lastActivityAt': '2026-10-11T01:00:00Z',
};
Map<String, dynamic> listState(int version, {int unread = 1}) => {
  'version': version,
  'totalRooms': 1,
  'totalUnread': unread,
};
ResponseBody jsonResponse(dynamic data, {int status = 200}) =>
    ResponseBody.fromString(
      jsonEncode(status == 200 ? {'success': true, 'data': data} : data),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
Map<String, dynamic> historyResponse(
  List<Map<String, dynamic>> messages, {
  String? next,
}) => {
  'messages': messages,
  'hasMore': next != null,
  'nextCursor': next,
  'limit': 20,
  'total': messages.length,
  'page': 1,
  'totalPages': 1,
};
Map<String, dynamic> listResponse(
  List<Map<String, dynamic>> rooms, {
  int page = 1,
  int pages = 1,
}) => {
  'rooms': rooms,
  'page': page,
  'total': 1,
  'limit': 20,
  'totalPages': pages,
  'listSnapshot': 'snapshot',
  'listSnapshotExpiresAt': '2099-10-11T01:00:00Z',
  'listState': listState(1),
};

class ChatAdapter implements HttpClientAdapter {
  ChatAdapter({this.eventPath = '/api/chatroom/events'});
  final String eventPath;
  final requests = <RequestOptions>[];
  final connections = <StreamController<Uint8List>>[];
  Future<ResponseBody> Function(RequestOptions)? handler;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (options.path == eventPath) {
      final connection = StreamController<Uint8List>();
      connections.add(connection);
      cancelFuture?.then((_) {
        if (!connection.isClosed) unawaited(connection.close());
      });
      return ResponseBody(
        connection.stream,
        200,
        headers: {
          'content-type': ['text/event-stream'],
        },
      );
    }
    if (handler != null) return handler!(options);
    if (options.path.endsWith('/list')) return jsonResponse(listResponse([]));
    return jsonResponse(historyResponse([]));
  }

  void event(String type, Map<String, dynamic> data, {String? id}) {
    connections.last.add(
      Uint8List.fromList(
        utf8.encode(
          '${id == null ? '' : 'id: $id\n'}event: $type\ndata: ${jsonEncode(data)}\n\n',
        ),
      ),
    );
  }

  @override
  void close({bool force = false}) {
    for (final c in connections) {
      if (!c.isClosed) unawaited(c.close());
    }
  }
}

Future<void> settle() async {
  for (var i = 0; i < 12; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}
