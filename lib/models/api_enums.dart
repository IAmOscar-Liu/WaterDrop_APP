// ignore_for_file: constant_identifier_names

enum OAuthProvider {
  google,
  apple,
  github,
  facebook,
  line,
  password,
  other;

  String get wireValue => name;

  static OAuthProvider fromWire(String? value) {
    return switch (value) {
      "google" => OAuthProvider.google,
      "apple" => OAuthProvider.apple,
      "github" => OAuthProvider.github,
      "facebook" => OAuthProvider.facebook,
      "line" => OAuthProvider.line,
      "password" => OAuthProvider.password,
      "other" => OAuthProvider.other,
      _ => OAuthProvider.other,
    };
  }
}

enum ProductStatus {
  active,
  inactive;

  String get wireValue => name;

  static ProductStatus fromWire(
    String? value, {
    ProductStatus fallback = ProductStatus.inactive,
  }) {
    return switch (value) {
      "active" => ProductStatus.active,
      "inactive" => ProductStatus.inactive,
      _ => fallback,
    };
  }
}

enum ProductType {
  normal,
  refrigeration,
  virtual;

  String get wireValue => name;

  static ProductType fromWire(String? value) {
    return switch (value) {
      "refrigeration" => ProductType.refrigeration,
      "virtual" => ProductType.virtual,
      "normal" => ProductType.normal,
      _ => ProductType.normal,
    };
  }
}

enum ChatRoomStatus {
  active,
  inactive;

  String get wireValue => name;

  static ChatRoomStatus fromWire(String? value) {
    return switch (value) {
      "inactive" => ChatRoomStatus.inactive,
      "active" => ChatRoomStatus.active,
      _ => ChatRoomStatus.inactive,
    };
  }
}

enum ChatMessageSenderType {
  user,
  admin,
  seller;

  String get wireValue => name;

  static ChatMessageSenderType fromWire(String? value) {
    return switch (value) {
      "admin" => ChatMessageSenderType.admin,
      "seller" => ChatMessageSenderType.seller,
      "user" => ChatMessageSenderType.user,
      _ => ChatMessageSenderType.user,
    };
  }
}

enum OrderPayment {
  Credit,
  ATM;

  String get wireValue => name;

  static OrderPayment fromWire(String? value) {
    return switch (value) {
      "ATM" => OrderPayment.ATM,
      "Credit" => OrderPayment.Credit,
      _ => OrderPayment.Credit,
    };
  }

  String get displayName {
    return switch (this) {
      OrderPayment.Credit => "信用卡",
      OrderPayment.ATM => "ATM轉帳",
    };
  }
}

enum OrderStatus {
  pending,
  paymentProcessing,
  paid,
  failed,
  expired,
  canceled;

  String get wireValue {
    return switch (this) {
      OrderStatus.paymentProcessing => "payment-processing",
      _ => name,
    };
  }

  static OrderStatus fromWire(String? value) {
    return switch (value) {
      "pending" => OrderStatus.pending,
      "payment-processing" => OrderStatus.paymentProcessing,
      "paid" => OrderStatus.paid,
      "failed" => OrderStatus.failed,
      "expired" => OrderStatus.expired,
      "canceled" => OrderStatus.canceled,
      _ => OrderStatus.pending,
    };
  }

  String get displayName {
    return switch (this) {
      OrderStatus.paid => "交易成功",
      OrderStatus.paymentProcessing => "待付款",
      OrderStatus.pending => "PENDING",
      OrderStatus.failed => "FAILED",
      OrderStatus.expired => "EXPIRED",
      OrderStatus.canceled => "CANCELED",
    };
  }
}

enum RefundStatus {
  pending,
  processing,
  completed,
  cancelled;

  String get wireValue => name;

  static RefundStatus fromWire(String? value) {
    return switch (value) {
      "processing" => RefundStatus.processing,
      "completed" => RefundStatus.completed,
      "cancelled" => RefundStatus.cancelled,
      "pending" => RefundStatus.pending,
      _ => RefundStatus.pending,
    };
  }
}

enum DeliveryStatus {
  pending,
  shipped,
  readyForPickup,
  delivered,
  returned,
  cancelled,
  exception,
  unknown;

  String get wireValue {
    return switch (this) {
      DeliveryStatus.readyForPickup => "ready_for_pickup",
      _ => name,
    };
  }

  static DeliveryStatus fromWire(String? value) {
    return switch (value) {
      "pending" => DeliveryStatus.pending,
      "shipped" => DeliveryStatus.shipped,
      "ready_for_pickup" => DeliveryStatus.readyForPickup,
      "delivered" => DeliveryStatus.delivered,
      "returned" => DeliveryStatus.returned,
      "cancelled" => DeliveryStatus.cancelled,
      "exception" => DeliveryStatus.exception,
      "unknown" => DeliveryStatus.unknown,
      _ => DeliveryStatus.unknown,
    };
  }
}

enum DeliveryLogisticsType {
  CVS,
  homeDelivery,
  virtual;

  String get wireValue {
    return switch (this) {
      DeliveryLogisticsType.homeDelivery => "home_delivery",
      _ => name,
    };
  }

  static DeliveryLogisticsType fromWire(String? value) {
    return switch (value) {
      "CVS" => DeliveryLogisticsType.CVS,
      "home_delivery" => DeliveryLogisticsType.homeDelivery,
      "virtual" => DeliveryLogisticsType.virtual,
      _ => DeliveryLogisticsType.virtual,
    };
  }
}

enum AdvertisementStatus {
  active,
  paused,
  depleted,
  archived;

  String get wireValue => name;

  static AdvertisementStatus fromWire(String? value) {
    return switch (value) {
      "paused" => AdvertisementStatus.paused,
      "depleted" => AdvertisementStatus.depleted,
      "archived" => AdvertisementStatus.archived,
      "active" => AdvertisementStatus.active,
      _ => AdvertisementStatus.archived,
    };
  }
}

enum AdvertisementTransactionType {
  deposit;

  String get wireValue => name;

  static AdvertisementTransactionType fromWire(String? value) {
    return switch (value) {
      "deposit" => AdvertisementTransactionType.deposit,
      _ => AdvertisementTransactionType.deposit,
    };
  }
}

enum NotificationType {
  systemAlert,
  orderStatus,
  promotion,
  coinsEarned,
  chatMessage,
  other;

  String get wireValue {
    return switch (this) {
      NotificationType.systemAlert => "system_alert",
      NotificationType.orderStatus => "order_status",
      NotificationType.coinsEarned => "coins_earned",
      NotificationType.chatMessage => "chat_message",
      _ => name,
    };
  }

  static NotificationType fromWire(String? value) {
    return switch (value) {
      "system_alert" => NotificationType.systemAlert,
      "order_status" => NotificationType.orderStatus,
      "promotion" => NotificationType.promotion,
      "coins_earned" => NotificationType.coinsEarned,
      "chat_message" => NotificationType.chatMessage,
      "other" => NotificationType.other,
      _ => NotificationType.other,
    };
  }

  String get displayName {
    return switch (this) {
      NotificationType.systemAlert => "系統通知",
      NotificationType.orderStatus => "訂單狀態",
      NotificationType.promotion => "促銷優惠",
      NotificationType.coinsEarned => "賺取金幣",
      NotificationType.chatMessage => "聊天訊息",
      NotificationType.other => "其他",
    };
  }
}
