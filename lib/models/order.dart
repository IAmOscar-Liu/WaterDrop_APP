import 'package:flutter_ad_ecommerce/models/product.dart';
import 'package:flutter_ad_ecommerce/utils/parse_utils.dart';

class Order {
  final String id;
  final String userId;
  final String? accountId;
  final String merchantTradeNo;
  final double subTotal;
  final double shippingCost;
  final double shippingCostDeduction;
  final double transactionFee;
  final double totalAmount;
  final int discountCoin;
  final String orderStatus;
  final String orderPayment;
  final double? transactionFeeRateAtSale;
  final String? userLevelAtSale;
  final int? userMaxDiscountAtSale;
  final Map<String, dynamic>? metadata;
  final List<OrderItem> items;
  final List<Delivery> deliveries;
  final dynamic shippingInfo;
  final dynamic paymentInfo;

  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;

  const Order({
    required this.id,
    required this.userId,
    this.accountId,
    required this.merchantTradeNo,
    required this.subTotal,
    required this.shippingCost,
    required this.shippingCostDeduction,
    required this.transactionFee,
    required this.totalAmount,
    required this.discountCoin,
    required this.orderStatus,
    required this.orderPayment,
    this.transactionFeeRateAtSale,
    this.userLevelAtSale,
    this.userMaxDiscountAtSale,
    this.metadata,
    required this.items,
    required this.deliveries,
    this.shippingInfo,
    this.paymentInfo,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
  });

  factory Order.fromApiResponseMap(Map<String, dynamic> map) {
    List<OrderItem> items = [];
    if (map['items'] is List) {
      for (var item in map['items']) {
        items.add(OrderItem.fromApiResponseMap(item));
      }
    }
    List<Delivery> deliveries = [];
    if (map['deliveries'] is List) {
      for (var delivery in map['deliveries']) {
        deliveries.add(Delivery.fromApiResponseMap(delivery));
      }
    }

    return Order(
      id: ParseUtils.parseString(map['id']) ?? "",
      userId: ParseUtils.parseString(map['userId']) ?? "",
      accountId: ParseUtils.parseString(map['accountId']),
      merchantTradeNo: ParseUtils.parseString(map['merchantTradeNo']) ?? "",
      subTotal: ParseUtils.parseDouble(map['subTotal']) ?? 0,
      shippingCost: ParseUtils.parseDouble(map['shippingCost']) ?? 0,
      shippingCostDeduction:
          ParseUtils.parseDouble(map['shippingCostDeduction']) ?? 0,
      transactionFee: ParseUtils.parseDouble(map['transactionFee']) ?? 0,
      totalAmount: ParseUtils.parseDouble(map['totalAmount']) ?? 0,
      discountCoin: ParseUtils.parseInt(map['discountCoin']) ?? 0,
      orderStatus: ParseUtils.parseString(map['orderStatus']) ?? "pending",
      orderPayment: ParseUtils.parseString(map['orderPayment']) ?? "Credit",
      transactionFeeRateAtSale: ParseUtils.parseDouble(
        map['transactionFeeRateAtSale'],
      ),
      userLevelAtSale: ParseUtils.parseString(map['userLevelAtSale']),
      userMaxDiscountAtSale: ParseUtils.parseInt(map['userMaxDiscountAtSale']),
      metadata: map['metadata'] is Map ? map['metadata'] : null,
      items: items,
      deliveries: deliveries,
      createdAt: ParseUtils.parseDateTime(map['createdAt']) ?? DateTime.now(),
      updatedAt: ParseUtils.parseDateTime(map['updatedAt']) ?? DateTime.now(),
      completedAt: ParseUtils.parseDateTime(map['completedAt']),
      shippingInfo: map['shippingInfo'] is Map ? map['shippingInfo'] : null,
      paymentInfo: map['paymentInfo'] is Map ? map['paymentInfo'] : null,
    );
  }

  Order copyWith({
    String? id,
    String? userId,
    String? accountId,
    String? merchantTradeNo,
    double? subTotal,
    double? shippingCost,
    double? shippingCostDeduction,
    double? transactionFee,
    double? totalAmount,
    int? discountCoin,
    String? orderStatus,
    String? orderPayment,
    String? userLevelAtSale,
    int? userMaxDiscountAtSale,
    Map<String, dynamic>? metadata,
    List<OrderItem>? items,
    List<Delivery>? deliveries,
    dynamic shippingInfo,
    dynamic paymentInfo,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? completedAt,
  }) {
    return Order(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      accountId: accountId ?? this.accountId,
      merchantTradeNo: merchantTradeNo ?? this.merchantTradeNo,
      subTotal: subTotal ?? this.subTotal,
      shippingCost: shippingCost ?? this.shippingCost,
      shippingCostDeduction:
          shippingCostDeduction ?? this.shippingCostDeduction,
      transactionFee: transactionFee ?? this.transactionFee,
      totalAmount: totalAmount ?? this.totalAmount,
      discountCoin: discountCoin ?? this.discountCoin,
      orderStatus: orderStatus ?? this.orderStatus,
      orderPayment: orderPayment ?? this.orderPayment,
      userLevelAtSale: userLevelAtSale ?? this.userLevelAtSale,
      userMaxDiscountAtSale:
          userMaxDiscountAtSale ?? this.userMaxDiscountAtSale,
      metadata: metadata ?? this.metadata,
      items: items ?? this.items,
      deliveries: deliveries ?? this.deliveries,
      shippingInfo: shippingInfo ?? this.shippingInfo,
      paymentInfo: paymentInfo ?? this.paymentInfo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

class OrderItem {
  final String id;
  final String orderId;
  final String productId;
  final int quantity;
  final double unitPriceAtSale;
  final String productNameAtSale;
  final double lineTotal;
  final DateTime createdAt;
  final Product? product;

  const OrderItem({
    required this.id,
    required this.orderId,
    required this.productId,
    required this.quantity,
    required this.unitPriceAtSale,
    required this.productNameAtSale,
    required this.lineTotal,
    required this.createdAt,
    this.product,
  });

  factory OrderItem.fromApiResponseMap(Map<String, dynamic> map) {
    return OrderItem(
      id: ParseUtils.parseString(map['id']) ?? "",
      orderId: ParseUtils.parseString(map['orderId']) ?? "",
      productId: ParseUtils.parseString(map['productId']) ?? "",
      quantity: ParseUtils.parseInt(map['quantity']) ?? 0,
      unitPriceAtSale: ParseUtils.parseDouble(map['unitPriceAtSale']) ?? 0,
      productNameAtSale: ParseUtils.parseString(map['productNameAtSale']) ?? '',
      lineTotal: ParseUtils.parseDouble(map['lineTotal']) ?? 0,
      createdAt: ParseUtils.parseDateTime(map['createdAt']) ?? DateTime.now(),
      product: map['product'] is Map
          ? Product.fromApiResponseMap(map['product'])
          : null,
    );
  }

  OrderItem copyWith({
    String? id,
    String? orderId,
    String? productId,
    int? quantity,
    double? unitPriceAtSale,
    String? productNameAtSale,
    double? lineTotal,
    DateTime? createdAt,
    Product? product,
  }) {
    return OrderItem(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      productId: productId ?? this.productId,
      quantity: quantity ?? this.quantity,
      unitPriceAtSale: unitPriceAtSale ?? this.unitPriceAtSale,
      productNameAtSale: productNameAtSale ?? this.productNameAtSale,
      lineTotal: lineTotal ?? this.lineTotal,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class Delivery {
  final String id;
  final String orderId;
  final String merchantTradeNo;
  final String status;
  final double goodsAmount;
  final String? allPayLogisticsID;
  final String logisticsType;
  final String logisticsSubType;
  final String? cvsPaymentNo;
  final String? cvsValidationNo;
  final String? rtnCode;
  final String? rtnMsg;
  final String? receiverStoreId;
  final Map<String, dynamic>? cvsStoreInfo;
  final Map<String, dynamic>? metadata;
  final List<DeliveryItem> items;
  final List<DeliveryLog> logs;
  final double fee;
  final double feeDeduction;
  final DateTime createdAt;
  final DateTime updatedAt;

  Delivery({
    required this.id,
    required this.orderId,
    required this.merchantTradeNo,
    required this.status,
    required this.goodsAmount,
    this.allPayLogisticsID,
    this.cvsPaymentNo,
    this.cvsValidationNo,
    required this.logisticsType,
    required this.logisticsSubType,
    this.rtnCode,
    this.rtnMsg,
    this.receiverStoreId,
    this.cvsStoreInfo,
    this.metadata,
    required this.items,
    required this.logs,
    required this.fee,
    required this.feeDeduction,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Delivery.fromApiResponseMap(Map<String, dynamic> map) {
    return Delivery(
      id: ParseUtils.parseString(map['id']) ?? "",
      orderId: ParseUtils.parseString(map['orderId']) ?? "",
      merchantTradeNo: ParseUtils.parseString(map['merchantTradeNo']) ?? "",
      status: ParseUtils.parseString(map['status']) ?? "",
      goodsAmount: ParseUtils.parseDouble(map['GoodsAmount']) ?? 0,
      allPayLogisticsID: ParseUtils.parseString(map['AllPayLogisticsID']),
      cvsPaymentNo: ParseUtils.parseString(map['CVSPaymentNo']),
      cvsValidationNo: ParseUtils.parseString(map['CVSValidationNo']),
      logisticsType: ParseUtils.parseString(map['LogisticsType']) ?? "",
      logisticsSubType: ParseUtils.parseString(map['LogisticsSubType']) ?? "",
      rtnCode: ParseUtils.parseString(map['RtnCode']),
      rtnMsg: ParseUtils.parseString(map['RtnMsg']),
      receiverStoreId: ParseUtils.parseString(map['ReceiverStoreId']),
      cvsStoreInfo: map['cvsStoreInfo'] is Map ? map['cvsStoreInfo'] : null,
      metadata: map['metadata'] is Map ? map['metadata'] : null,
      items: map['items'] is List
          ? List.generate(
              map['items'].length,
              (index) => DeliveryItem.fromApiResponseMap(map['items'][index]),
            )
          : [],
      logs: map['logs'] is List
          ? List.generate(
              map['logs'].length,
              (index) => DeliveryLog.fromApiResponseMap(map['logs'][index]),
            )
          : [],
      fee: ParseUtils.parseDouble(map['fee']) ?? 0,
      feeDeduction: ParseUtils.parseDouble(map['feeDeduction']) ?? 0,
      createdAt: ParseUtils.parseDateTime(map['createdAt']) ?? DateTime.now(),
      updatedAt: ParseUtils.parseDateTime(map['updatedAt']) ?? DateTime.now(),
    );
  }
}

class DeliveryItem {
  final String id;
  final String productId;
  final String productNameAtSale;

  DeliveryItem({
    required this.id,
    required this.productId,
    required this.productNameAtSale,
  });

  factory DeliveryItem.fromApiResponseMap(Map<String, dynamic> map) {
    return DeliveryItem(
      id: ParseUtils.parseString(map['id']) ?? "",
      productId: ParseUtils.parseString(map['productId']) ?? "",
      productNameAtSale: ParseUtils.parseString(map['productNameAtSale']) ?? "",
    );
  }
}

class DeliveryLog {
  final String id;
  final String deliveryId;
  final String status;
  final String rtnCode;
  final String rtnMsg;
  final DateTime createdAt;

  DeliveryLog({
    required this.id,
    required this.deliveryId,
    required this.status,
    required this.rtnCode,
    required this.rtnMsg,
    required this.createdAt,
  });

  factory DeliveryLog.fromApiResponseMap(Map<String, dynamic> map) {
    return DeliveryLog(
      id: ParseUtils.parseString(map['id']) ?? "",
      deliveryId: ParseUtils.parseString(map['deliveryId']) ?? "",
      status: ParseUtils.parseString(map['status']) ?? "",
      rtnCode: ParseUtils.parseString(map['RtnCode']) ?? "",
      rtnMsg: ParseUtils.parseString(map['RtnMsg']) ?? "",
      createdAt: ParseUtils.parseDateTime(map["createdAt"]) ?? DateTime.now(),
    );
  }
}

class OrderPagination {
  List<Order> orders;
  int total;
  int page;
  int limit;
  int totalPages;
  OrderPagination({
    required this.orders,
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  OrderPagination copyWith({
    List<Order>? orders,
    int? total,
    int? page,
    int? limit,
    int? totalPages,
  }) {
    return OrderPagination(
      orders: orders ?? this.orders,
      total: total ?? this.total,
      page: page ?? this.page,
      limit: limit ?? this.limit,
      totalPages: totalPages ?? this.totalPages,
    );
  }
}
