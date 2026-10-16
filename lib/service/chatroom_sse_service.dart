import 'user_sse_service.dart';

export 'user_sse_service.dart' show UserSseFrame;

typedef ChatSseFrame = UserSseFrame;
Stream<ChatSseFrame> decodeChatSse(Stream<List<int>> bytes) =>
    decodeUserSse(bytes);

/// Chat keeps its own transport instance and checkpoint.
class ChatroomSseService extends UserSseService {
  ChatroomSseService({
    required super.dio,
    required super.refreshToken,
    required super.onReady,
    required super.onEvent,
    required super.onReset,
    required super.onStatus,
    super.watchdog,
  }) : super(
         path: '/api/chatroom/events',
         cursorInvalidCode: 'CHAT_STREAM_CURSOR_INVALID',
       );
}
