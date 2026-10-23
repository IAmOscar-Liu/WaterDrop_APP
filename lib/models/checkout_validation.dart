import 'package:flutter_ad_ecommerce/models/product.dart';

/// A completed batch check, including business failures and the full owned cart.
class CheckoutValidation {
  final bool canCheckout;
  final List<CartItem> cartItems;
  final List<CartItem> selectedItems;
  final List<CartItem> unavailableItems;
  final String message;

  CheckoutValidation._(
    this.canCheckout,
    this.cartItems,
    this.selectedItems,
    this.unavailableItems,
    this.message,
  );

  factory CheckoutValidation.fromResponse(
    dynamic response,
    List<CartItem> requested,
  ) {
    if (response is! Map ||
        response['success'] != true ||
        response['data'] is! Map) {
      throw const FormatException('Invalid checkout validation response');
    }
    final data = response['data'] as Map;
    if (data['canCheckout'] is! bool ||
        data['cartItems'] is! List ||
        data['items'] is! List ||
        data['items'].length != requested.length ||
        data['checkedAt'] is! String ||
        DateTime.tryParse(data['checkedAt']) == null) {
      throw const FormatException('Incomplete checkout validation response');
    }
    final messages = <String>{};
    List<Map> issues(dynamic value) {
      if (value is! List) {
        throw const FormatException('Missing checkout issues');
      }
      return value.map((issue) {
        if (issue is! Map ||
            issue['code'] is! String ||
            issue['message'] is! String) {
          throw const FormatException('Invalid checkout issue');
        }
        return issue;
      }).toList();
    }

    final overallIssues = issues(data['issues']);
    messages.addAll(overallIssues.map((issue) => issue['message'] as String));
    final cart = (data['cartItems'] as List).map((raw) {
      final row = Map<String, dynamic>.from(raw as Map);
      // Deleted product relations may be null; keep the owned row removable.
      row['product'] ??= {
        'id': row['productId'],
        'name': '商品已不存在',
        'status': 'inactive',
      };
      return CartItem.fromApiResponseMap(row);
    }).toList();
    final byId = {for (final row in cart) row.id.toLowerCase(): row};
    if (byId.length != cart.length) {
      throw const FormatException('Duplicate cart rows');
    }
    final selected = <CartItem>[];
    final unavailable = <CartItem>[];
    var allPassed = overallIssues.isEmpty;
    for (var i = 0; i < requested.length; i++) {
      final request = requested[i];
      final result = data['items'][i];
      if (result is! Map ||
          result['cartItemId'] is! String ||
          (result['cartItemId'] as String).toLowerCase() !=
              request.id.toLowerCase() ||
          result['requestedQuantity'] != request.quantity ||
          result['canCheckout'] is! bool) {
        throw const FormatException('Mismatched checkout result');
      }
      final rowIssues = issues(result['issues']);
      final current = byId[request.id.toLowerCase()];
      final name = result['productName'] ?? request.product.name;
      final variant = result['variantName'];
      final label = variant is String && variant.trim().isNotEmpty
          ? '$name / $variant'
          : '$name';
      for (final issue in rowIssues) {
        messages.add(
          issue['code'] == 'INSUFFICIENT_STOCK'
              ? '「$label」庫存不足（需求：${request.quantity}，剩餘：${result['availableStock']}）'
              : '「$label」${issue['message']}',
        );
      }
      if (current != null) selected.add(current);
      final sameVariant =
          current != null &&
          current.productVariantId.toLowerCase() ==
              request.productVariantId.toLowerCase();
      if (sameVariant &&
          rowIssues.any(
            (issue) =>
                issue['code'] == 'PRODUCT_UNAVAILABLE' ||
                issue['code'] == 'VARIANT_UNAVAILABLE',
          )) {
        unavailable.add(current);
      }
      final stock = result['availableStock'];
      final price = result['currentUnitPrice'];
      allPassed =
          allPassed &&
          result['canCheckout'] == true &&
          rowIssues.isEmpty &&
          sameVariant &&
          current.checked &&
          current.quantity == request.quantity &&
          current.variant != null &&
          current.unitPrice == request.unitPrice &&
          result['currentQuantity'] == request.quantity &&
          result['productVariantId'] is String &&
          (result['productVariantId'] as String).toLowerCase() ==
              request.productVariantId.toLowerCase() &&
          price is num &&
          price.isFinite &&
          price >= 0 &&
          price == request.unitPrice &&
          stock is int &&
          stock >= request.quantity;
    }
    final checkedIds = cart
        .where((row) => row.checked)
        .map((row) => row.id.toLowerCase())
        .toSet();
    final requestedIds = requested.map((row) => row.id.toLowerCase()).toSet();
    allPassed =
        allPassed &&
        checkedIds.length == requestedIds.length &&
        checkedIds.containsAll(requestedIds);
    if (data['canCheckout'] == true && !allPassed) {
      throw const FormatException('Inconsistent checkout approval');
    }
    return CheckoutValidation._(
      data['canCheckout'],
      cart,
      selected,
      unavailable,
      messages.isEmpty ? '購物車內容已變更，請重新確認後再結帳。' : messages.join('\n'),
    );
  }
}
