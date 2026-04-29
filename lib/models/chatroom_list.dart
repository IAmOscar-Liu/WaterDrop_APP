import 'package:flutter_ad_ecommerce/models/chatroom.dart';

class ChatRoomPagination {
  List<Chatroom> rooms;
  int total;
  int page;
  int limit;
  int totalPages;

  ChatRoomPagination({
    required this.rooms,
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  ChatRoomPagination copyWith({
    List<Chatroom>? rooms,
    int? total,
    int? page,
    int? limit,
    int? totalPages,
  }) {
    return ChatRoomPagination(
      rooms: rooms ?? this.rooms,
      total: total ?? this.total,
      page: page ?? this.page,
      limit: limit ?? this.limit,
      totalPages: totalPages ?? this.totalPages,
    );
  }
}
