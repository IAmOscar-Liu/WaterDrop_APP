// lib/models.dart
import 'package:flutter_ad_ecommerce/utils/parse_utils.dart';

class Message {
  final String id;
  final String userId;
  final String? orderId;
  final String type;
  final String title;
  final String body;
  final bool isRead;

  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? metadata;

  Message({
    required this.id,
    required this.userId,
    this.orderId,
    required this.type,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
    required this.updatedAt,
    this.metadata,
  });

  factory Message.fromApiResponseMap(Map<String, dynamic> map) {
    return Message(
      id: ParseUtils.parseString(map['id']) ?? "",
      userId: ParseUtils.parseString(map['userId']) ?? "",
      orderId: ParseUtils.parseString(map['orderId']),
      type: ParseUtils.parseString(map['type']) ?? "",
      title: ParseUtils.parseString(map['title']) ?? "",
      body: ParseUtils.parseString(map['body']) ?? "",
      isRead: map['isRead'] == true,
      createdAt: ParseUtils.parseDateTime(map['createdAt']) ?? DateTime.now(),
      updatedAt: ParseUtils.parseDateTime(map['updatedAt']) ?? DateTime.now(),
      metadata: map['metadata'] is Map
          ? map['metadata']
          : null, // Handle nullable metadata
    );
  }

  Message copyWith({
    String? id,
    String? userId,
    String? orderId,
    String? type,
    String? title,
    String? body,
    bool? isRead,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
  }) {
    return Message(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      orderId: orderId ?? this.orderId,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }
}

class MessagePagination {
  List<Message> messages;
  int total;
  int page;
  int limit;
  int totalPages;
  MessagePagination({
    required this.messages,
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  MessagePagination copyWith({
    List<Message>? messages,
    int? total,
    int? page,
    int? limit,
    int? totalPages,
  }) {
    return MessagePagination(
      messages: messages ?? this.messages,
      total: total ?? this.total,
      page: page ?? this.page,
      limit: limit ?? this.limit,
      totalPages: totalPages ?? this.totalPages,
    );
  }
}

class MessageStats {
  final int total;
  final int systemAlert;
  final int promotion;
  final int coinsEarned;
  final int orderStatus;
  final int chatMessage;
  final int other;

  MessageStats({
    required this.total,
    required this.systemAlert,
    required this.promotion,
    required this.coinsEarned,
    required this.orderStatus,
    required this.chatMessage,
    required this.other,
  });

  factory MessageStats.fromApiResponseMap(Map<String, dynamic> map) {
    return MessageStats(
      total: ParseUtils.parseInt(map['total']) ?? 0,
      systemAlert: ParseUtils.parseInt(map['system_alert']) ?? 0,
      promotion: ParseUtils.parseInt(map['promotion']) ?? 0,
      coinsEarned: ParseUtils.parseInt(map['coins_earned']) ?? 0,
      orderStatus: ParseUtils.parseInt(map['order_status']) ?? 0,
      chatMessage: ParseUtils.parseInt(map['chat_message']) ?? 0,
      other: ParseUtils.parseInt(map['other']) ?? 0,
    );
  }

  MessageStats copyWith({
    int? total,
    int? systemAlert,
    int? promotion,
    int? coinsEarned,
    int? orderStatus,
    int? chatMessage,
    int? other,
  }) {
    return MessageStats(
      total: total ?? this.total,
      systemAlert: systemAlert ?? this.systemAlert,
      promotion: promotion ?? this.promotion,
      coinsEarned: coinsEarned ?? this.coinsEarned,
      orderStatus: orderStatus ?? this.orderStatus,
      chatMessage: chatMessage ?? this.chatMessage,
      other: other ?? this.other,
    );
  }
}
