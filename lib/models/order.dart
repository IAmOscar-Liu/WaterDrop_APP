import 'package:flutter_ad_ecommerce/models/api_enums.dart';
import 'package:flutter_ad_ecommerce/models/product.dart';
import 'package:flutter_ad_ecommerce/utils/parse_utils.dart';

class VariantAtSale {
  final String? name;
  final String? sku;
  final Map<String, dynamic>? optionValues;
  final double price;

  const VariantAtSale({this.name, this.sku, this.optionValues, this.price = 0});

  factory VariantAtSale.fromApiResponseMap(Map<String, dynamic> map) {
    return VariantAtSale(
      name: ParseUtils.parseString(map['name']),
      sku: ParseUtils.parseString(map['sku']),
      optionValues: map['optionValues'] is Map
          ? Map<String, dynamic>.from(map['optionValues'])
          : null,
      price: ParseUtils.parseDouble(map['price']) ?? 0,
    );
  }

  String get displayName {
    final trimmedName = name?.trim();
    if (trimmedName != null && trimmedName.isNotEmpty) return trimmedName;

    final optionText =
        optionValues?.entries
            .where(
              (entry) =>
                  entry.value != null && entry.value.toString().isNotEmpty,
            )
            .map((entry) => "${entry.key}: ${entry.value}")
            .join(" / ") ??
        "";
    if (optionText.isNotEmpty) return optionText;

    final trimmedSku = sku?.trim();
    if (trimmedSku != null && trimmedSku.isNotEmpty) return trimmedSku;

    return "";
  }
}

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
  final double discountCoin;
  final Map<String, double>? coinInfo;
  final OrderStatus orderStatus;
  final OrderPayment orderPayment;
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
    this.coinInfo,
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
      discountCoin: ParseUtils.parseDouble(map['discountCoin']) ?? 0,
      coinInfo: map['coinInfo'] is Map
          ? Map<String, double>.fromEntries(
              (map['coinInfo'] as Map).entries.map(
                (entry) => MapEntry(
                  entry.key.toString(),
                  ParseUtils.parseDouble(entry.value) ?? 0,
                ),
              ),
            )
          : null,
      orderStatus: OrderStatus.fromWire(
        ParseUtils.parseString(map['orderStatus']),
      ),
      orderPayment: OrderPayment.fromWire(
        ParseUtils.parseString(map['orderPayment']),
      ),
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
    double? discountCoin,
    Map<String, double>? coinInfo,
    OrderStatus? orderStatus,
    OrderPayment? orderPayment,
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
      coinInfo: coinInfo ?? this.coinInfo,
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
  final String productVariantId;
  final int quantity;
  final double unitPriceAtSale;
  final String productNameAtSale;
  final String? variantNameAtSale;
  final String? variantSkuAtSale;
  final Map<String, dynamic>? variantOptionValuesAtSale;
  final VariantAtSale? variantAtSale;
  final String? variantImage;
  final double lineTotal;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Product? product;
  final bool canRefund;
  final int remainingRefundQuantity;
  final List<RefundItem> refundItems;

  const OrderItem({
    required this.id,
    required this.orderId,
    required this.productId,
    required this.productVariantId,
    required this.quantity,
    required this.unitPriceAtSale,
    required this.productNameAtSale,
    this.variantNameAtSale,
    this.variantSkuAtSale,
    this.variantOptionValuesAtSale,
    this.variantAtSale,
    this.variantImage,
    required this.lineTotal,
    required this.createdAt,
    required this.updatedAt,
    this.product,
    this.canRefund = false,
    this.remainingRefundQuantity = 0,
    this.refundItems = const [],
  });

  factory OrderItem.fromApiResponseMap(Map<String, dynamic> map) {
    return OrderItem(
      id: ParseUtils.parseString(map['id']) ?? "",
      orderId: ParseUtils.parseString(map['orderId']) ?? "",
      productId: ParseUtils.parseString(map['productId']) ?? "",
      productVariantId: ParseUtils.parseString(map['productVariantId']) ?? "",
      quantity: ParseUtils.parseInt(map['quantity']) ?? 0,
      unitPriceAtSale: ParseUtils.parseDouble(map['unitPriceAtSale']) ?? 0,
      productNameAtSale: ParseUtils.parseString(map['productNameAtSale']) ?? '',
      variantNameAtSale: ParseUtils.parseString(map['variantNameAtSale']),
      variantSkuAtSale: ParseUtils.parseString(map['variantSkuAtSale']),
      variantOptionValuesAtSale: map['variantOptionValuesAtSale'] is Map
          ? Map<String, dynamic>.from(map['variantOptionValuesAtSale'])
          : null,
      variantAtSale: map['variantAtSale'] is Map
          ? VariantAtSale.fromApiResponseMap(map['variantAtSale'])
          : null,
      variantImage: ParseUtils.parseString(map['variantImage']),
      lineTotal: ParseUtils.parseDouble(map['lineTotal']) ?? 0,
      createdAt: ParseUtils.parseDateTime(map['createdAt']) ?? DateTime.now(),
      updatedAt: ParseUtils.parseDateTime(map['updatedAt']) ?? DateTime.now(),
      product: map['product'] is Map
          ? Product.fromApiResponseMap(map['product'])
          : null,
      canRefund: map['canRefund'] == true,
      remainingRefundQuantity:
          ParseUtils.parseInt(map['remainingRefundQuantity']) ?? 0,
      refundItems: map['refundItems'] is List
          ? List.generate(
              map['refundItems'].length,
              (index) =>
                  RefundItem.fromApiResponseMap(map['refundItems'][index]),
            )
          : [],
    );
  }

  OrderItem copyWith({
    String? id,
    String? orderId,
    String? productId,
    String? productVariantId,
    int? quantity,
    double? unitPriceAtSale,
    String? productNameAtSale,
    String? variantNameAtSale,
    String? variantSkuAtSale,
    Map<String, dynamic>? variantOptionValuesAtSale,
    VariantAtSale? variantAtSale,
    String? variantImage,
    double? lineTotal,
    DateTime? createdAt,
    DateTime? updatedAt,
    Product? product,
    bool? canRefund,
    List<RefundItem>? refundItems,
  }) {
    return OrderItem(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      productId: productId ?? this.productId,
      productVariantId: productVariantId ?? this.productVariantId,
      quantity: quantity ?? this.quantity,
      unitPriceAtSale: unitPriceAtSale ?? this.unitPriceAtSale,
      productNameAtSale: productNameAtSale ?? this.productNameAtSale,
      variantNameAtSale: variantNameAtSale ?? this.variantNameAtSale,
      variantSkuAtSale: variantSkuAtSale ?? this.variantSkuAtSale,
      variantOptionValuesAtSale:
          variantOptionValuesAtSale ?? this.variantOptionValuesAtSale,
      variantAtSale: variantAtSale ?? this.variantAtSale,
      variantImage: variantImage ?? this.variantImage,
      lineTotal: lineTotal ?? this.lineTotal,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      product: product ?? this.product,
      canRefund: canRefund ?? this.canRefund,
      refundItems: refundItems ?? this.refundItems,
    );
  }

  String get variantDisplayName {
    return variantAtSale?.displayName ?? "";
  }
}

class RefundLog {
  final String id;
  final String refundItemId;
  final RefundStatus status;
  final String? message;
  final DateTime createdAt;

  const RefundLog({
    required this.id,
    required this.refundItemId,
    required this.status,
    this.message,
    required this.createdAt,
  });

  factory RefundLog.fromApiResponseMap(Map<String, dynamic> map) {
    return RefundLog(
      id: ParseUtils.parseString(map['id']) ?? "",
      refundItemId: ParseUtils.parseString(map['refundItemId']) ?? "",
      status: RefundStatus.fromWire(ParseUtils.parseString(map['status'])),
      message: ParseUtils.parseString(map['message']),
      createdAt: ParseUtils.parseDateTime(map['createdAt']) ?? DateTime.now(),
    );
  }
}

class RefundItem {
  final String id;
  final String orderItemId;
  final int quantity;
  final RefundStatus status;
  final String? reason;
  final String? note;
  final double refundAmount;
  final double? paidRefundAmount;
  final double extraRefundAmount;
  final int? cashRefundAmount;
  final double cashRemainderCoins;
  final double coins;
  final double? returnableCoins;
  final Map<String, dynamic>? metadata;
  final Map<String, dynamic>? summary;
  final List<RefundLog> logs;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RefundItem({
    required this.id,
    required this.orderItemId,
    required this.quantity,
    required this.status,
    this.reason,
    this.note,
    required this.refundAmount,
    required this.paidRefundAmount,
    required this.extraRefundAmount,
    this.cashRefundAmount,
    required this.cashRemainderCoins,
    required this.coins,
    this.returnableCoins,
    this.metadata,
    this.summary,
    this.logs = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory RefundItem.fromApiResponseMap(Map<String, dynamic> map) {
    return RefundItem(
      id: ParseUtils.parseString(map['id']) ?? "",
      orderItemId: ParseUtils.parseString(map['orderItemId']) ?? "",
      quantity: ParseUtils.parseInt(map['quantity']) ?? 0,
      status: RefundStatus.fromWire(ParseUtils.parseString(map['status'])),
      reason: ParseUtils.parseString(map['reason']),
      note: ParseUtils.parseString(map['note']),
      refundAmount: ParseUtils.parseDouble(map['refundAmount']) ?? 0,
      paidRefundAmount: ParseUtils.parseDouble(map['paidRefundAmount']),
      extraRefundAmount: ParseUtils.parseDouble(map['extraRefundAmount']) ?? 0,
      cashRefundAmount: ParseUtils.parseInt(map['cashRefundAmount']),
      cashRemainderCoins:
          ParseUtils.parseDouble(map['cashRemainderCoins']) ?? 0,
      coins: ParseUtils.parseDouble(map['coins']) ?? 0,
      returnableCoins: ParseUtils.parseDouble(map['returnableCoins']),
      metadata: map['metadata'] is Map ? map['metadata'] : null,
      summary: map['summary'] is Map ? map['summary'] : null,
      logs: map['logs'] is List
          ? List.generate(
              map['logs'].length,
              (index) => RefundLog.fromApiResponseMap(map['logs'][index]),
            )
          : const [],
      createdAt: ParseUtils.parseDateTime(map['createdAt']) ?? DateTime.now(),
      updatedAt: ParseUtils.parseDateTime(map['updatedAt']) ?? DateTime.now(),
    );
  }
}

class Delivery {
  final String id;
  final String orderId;
  final String merchantTradeNo;
  final DeliveryStatus status;
  final double goodsAmount;
  final String? allPayLogisticsID;
  final DeliveryLogisticsType logisticsType;
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
      status: DeliveryStatus.fromWire(ParseUtils.parseString(map['status'])),
      goodsAmount: ParseUtils.parseDouble(map['GoodsAmount']) ?? 0,
      allPayLogisticsID: ParseUtils.parseString(map['AllPayLogisticsID']),
      cvsPaymentNo: ParseUtils.parseString(map['CVSPaymentNo']),
      cvsValidationNo: ParseUtils.parseString(map['CVSValidationNo']),
      logisticsType: DeliveryLogisticsType.fromWire(
        ParseUtils.parseString(map['LogisticsType']),
      ),
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
  final String productVariantId;
  final String productNameAtSale;
  final String? variantNameAtSale;
  final String? variantSkuAtSale;
  final Map<String, dynamic>? variantOptionValuesAtSale;
  final VariantAtSale? variantAtSale;
  final String? variantImage;

  DeliveryItem({
    required this.id,
    required this.productId,
    required this.productVariantId,
    required this.productNameAtSale,
    this.variantNameAtSale,
    this.variantSkuAtSale,
    this.variantOptionValuesAtSale,
    this.variantAtSale,
    this.variantImage,
  });

  factory DeliveryItem.fromApiResponseMap(Map<String, dynamic> map) {
    return DeliveryItem(
      id: ParseUtils.parseString(map['id']) ?? "",
      productId: ParseUtils.parseString(map['productId']) ?? "",
      productVariantId: ParseUtils.parseString(map['productVariantId']) ?? "",
      productNameAtSale: ParseUtils.parseString(map['productNameAtSale']) ?? "",
      variantNameAtSale: ParseUtils.parseString(map['variantNameAtSale']),
      variantSkuAtSale: ParseUtils.parseString(map['variantSkuAtSale']),
      variantOptionValuesAtSale: map['variantOptionValuesAtSale'] is Map
          ? Map<String, dynamic>.from(map['variantOptionValuesAtSale'])
          : null,
      variantAtSale: map['variantAtSale'] is Map
          ? VariantAtSale.fromApiResponseMap(map['variantAtSale'])
          : null,
      variantImage: ParseUtils.parseString(map['variantImage']),
    );
  }

  String get variantDisplayName {
    return variantAtSale?.displayName ?? "";
  }
}

class DeliveryLog {
  final String id;
  final String deliveryId;
  final DeliveryStatus status;
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
      status: DeliveryStatus.fromWire(ParseUtils.parseString(map['status'])),
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
