import 'package:flutter_ad_ecommerce/models/product.dart';
import 'package:flutter_ad_ecommerce/utils/parse_utils.dart';

// ignore_for_file: public_member_api_docs, sort_constructors_first
class Chatroom {
  final String id;
  final String userId;
  final String? accountId;
  final String? productId;

  final Product? product;
  final int? totalUnread;
  final ChatMessage? lastMessage;
  final ChatRoomOrder? order;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  Chatroom({
    required this.id,
    required this.userId,
    this.accountId,
    this.productId,
    this.product,
    this.totalUnread,
    this.lastMessage,
    this.order,
    this.createdAt,
    this.updatedAt,
  });

  Chatroom copyWith({
    String? id,
    String? userId,
    String? accountId,
    String? productId,
    Product? product,
    int? totalUnread,
    ChatMessage? lastMessage,
    ChatRoomOrder? order,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Chatroom(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      accountId: accountId ?? this.accountId,
      productId: productId ?? this.productId,
      product: product ?? this.product,
      totalUnread: totalUnread ?? this.totalUnread,
      lastMessage: lastMessage ?? this.lastMessage,
      order: order ?? this.order,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'userId': userId,
      'accountId': accountId,
      'productId': productId,
      'createdAt': createdAt?.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
    };
  }

  factory Chatroom.fromApiResponseMap(Map<String, dynamic> map) {
    return Chatroom(
      id: ParseUtils.parseString(map['id']) ?? "",
      userId: ParseUtils.parseString(map['userId']) ?? "",
      accountId: ParseUtils.parseString(map['accountId']),
      productId: ParseUtils.parseString(map['productId']),
      product: map['product'] is Map
          ? Product.fromApiResponseMap(map['product'])
          : null,
      totalUnread: ParseUtils.parseInt(map['totalUnread']),
      lastMessage: map['lastMessage'] is Map
          ? ChatMessage.fromApiResponseMap(map['lastMessage'])
          : null,
      order: map['order'] is Map
          ? ChatRoomOrder.fromApiResponseMap(map['order'])
          : null,
      createdAt: ParseUtils.parseDateTime(map['createdAt']),
      updatedAt: ParseUtils.parseDateTime(map['updatedAt']),
    );
  }
}

class ChatMessage {
  final String id;
  final String chatRoomId;
  final String senderType;
  final String content;
  final List<ChatMessageAttachment>? attachments;
  final bool isRead;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.chatRoomId,
    required this.senderType,
    required this.content,
    this.attachments,
    required this.isRead,
    required this.createdAt,
  });

  ChatMessage copyWith({
    String? id,
    String? chatRoomId,
    String? senderType,
    String? content,
    List<ChatMessageAttachment>? attachments,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      chatRoomId: chatRoomId ?? this.chatRoomId,
      senderType: senderType ?? this.senderType,
      content: content ?? this.content,
      attachments: attachments ?? this.attachments,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'chatRoomId': chatRoomId,
      'senderType': senderType,
      'content': content,
      'isRead': isRead,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory ChatMessage.pending({required String content}) {
    return ChatMessage(
      id: "pending",
      chatRoomId: "",
      senderType: "user",
      content: content,
      isRead: false,
      createdAt: DateTime.now(),
    );
  }

  factory ChatMessage.fromApiResponseMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: ParseUtils.parseString(map['id']) ?? "",
      chatRoomId: ParseUtils.parseString(map['chatRoomId']) ?? "",
      senderType: ParseUtils.parseString(map['senderType']) ?? "",
      content: ParseUtils.parseString(map['content']) ?? "",
      attachments: map["attachments"] is List
          ? List.generate(
              map["attachments"].length,
              (index) => ChatMessageAttachment.fromApiResponseMap(
                map["attachments"][index],
              ),
            )
          : null,
      isRead: map['isRead'] == true,
      createdAt: ParseUtils.parseDateTime(map['createdAt']) ?? DateTime.now(),
    );
  }
}

// "id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
// "name": "string",
// "createdAt": "2026-01-09T08:54:23.884Z",
// "updatedAt": "2026-01-09T08:54:23.884Z",
// "size": 0,
// "chatMessageId": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
// "url": "string",
// "type": "string"

class ChatMessageAttachment {
  final String id;
  final String url;
  final String? name;
  final String? mimeType;
  final double? size;
  final DateTime createdAt;
  final DateTime updatedAt;

  ChatMessageAttachment({
    required this.id,
    required this.url,
    this.name,
    this.mimeType,
    this.size,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ChatMessageAttachment.fromApiResponseMap(Map<String, dynamic> map) {
    return ChatMessageAttachment(
      id: ParseUtils.parseString(map['id']) ?? "",
      url: ParseUtils.parseString(map['url']) ?? "",
      name: ParseUtils.parseString(map['name']),
      mimeType: ParseUtils.parseString(map['mimeType']),
      size: ParseUtils.parseDouble(map['size']),
      createdAt: ParseUtils.parseDateTime(map['createdAt']) ?? DateTime.now(),
      updatedAt: ParseUtils.parseDateTime(map['updatedAt']) ?? DateTime.now(),
    );
  }
}

class ChatMessagePagination {
  List<ChatMessage> chatMessages;
  int total;
  int page;
  int limit;
  int totalPages;

  ChatMessagePagination({
    required this.chatMessages,
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  ChatMessagePagination copyWith({
    List<ChatMessage>? chatMessages,
    int? total,
    int? page,
    int? limit,
    int? totalPages,
  }) {
    return ChatMessagePagination(
      chatMessages: chatMessages ?? this.chatMessages,
      total: total ?? this.total,
      page: page ?? this.page,
      limit: limit ?? this.limit,
      totalPages: totalPages ?? this.totalPages,
    );
  }
}

// "order": {
//   "id": "0357ef7d-8e8a-47ee-8b64-b8450d32db3a",
//   "orderStatus": "paid",
//   "merchantTradeNo": "ed337ebb175c8518e3fd",
//   "totalAmount": 3000,
//   "discountCoin": 0,
//   "delivery": {
//     "RtnCode": "300",
//     "RtnMsg": "訂單處理中(綠界已收到訂單資料)"
//   }
// }

class ChatRoomOrder {
  final String id;
  final String orderStatus;
  final String merchantTradeNo;
  final int totalAmount;
  final int discountCoin;
  final ChatRoomOrderDelivery? delivery;

  ChatRoomOrder({
    required this.id,
    required this.orderStatus,
    required this.merchantTradeNo,
    required this.totalAmount,
    required this.discountCoin,
    this.delivery,
  });

  factory ChatRoomOrder.fromApiResponseMap(Map<String, dynamic> map) {
    return ChatRoomOrder(
      id: ParseUtils.parseString(map['id']) ?? "",
      orderStatus: ParseUtils.parseString(map['orderStatus']) ?? "",
      merchantTradeNo: ParseUtils.parseString(map['merchantTradeNo']) ?? "",
      totalAmount: ParseUtils.parseInt(map['totalAmount']) ?? 0,
      discountCoin: ParseUtils.parseInt(map['discountCoin']) ?? 0,
      delivery: map['delivery'] is Map
          ? ChatRoomOrderDelivery.fromApiResponseMap(map['delivery'])
          : null,
    );
  }
}

class ChatRoomOrderDelivery {
  final String logisticsType;
  final String? logisticsSubType;
  final String status;
  final String rtnCode;
  final String rtnMsg;

  ChatRoomOrderDelivery({
    required this.logisticsType,
    this.logisticsSubType,
    required this.status,
    required this.rtnCode,
    required this.rtnMsg,
  });

  factory ChatRoomOrderDelivery.fromApiResponseMap(Map<String, dynamic> map) {
    return ChatRoomOrderDelivery(
      logisticsType: ParseUtils.parseString(map['LogisticsType']) ?? "",
      logisticsSubType: ParseUtils.parseString(map['LogisticsSubType']),
      status: ParseUtils.parseString(map['status']) ?? "",
      rtnCode: ParseUtils.parseString(map['RtnCode']) ?? "",
      rtnMsg: ParseUtils.parseString(map['RtnMsg']) ?? "",
    );
  }
}
