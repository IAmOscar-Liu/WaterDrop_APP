/// Complete Part A response fixture; callers can override fields to test failures.
Map<String, dynamic> checkoutFixture(
  List<Map<String, dynamic>> requested, {
  List<Map<String, dynamic>>? cartItems,
  Map<String, List<String>> itemIssues = const {},
  List<String> overallIssues = const [],
  int stock = 10,
}) {
  final cart = cartItems ?? requested;
  const messages = {
    'PRODUCT_UNAVAILABLE': '商品已下架或不存在',
    'VARIANT_UNAVAILABLE': '規格已下架或不存在',
    'CART_ITEM_UNAVAILABLE': '商品已不存在',
    'CART_ITEM_CHANGED': '購物車內容已變更',
    'CART_SELECTION_CHANGED': '勾選商品已變更',
    'PRICE_CHANGED': '商品價格已變更',
    'PRICE_UNAVAILABLE': '無法確認商品價格',
    'STOCK_UNAVAILABLE': '無法確認商品庫存',
    'INSUFFICIENT_STOCK': '庫存不足',
  };
  List<Map<String, String>> issues(List<String> codes) => [
    for (final code in codes) {'code': code, 'message': messages[code] ?? code},
  ];
  return {
    'canCheckout':
        overallIssues.isEmpty && itemIssues.values.every((v) => v.isEmpty),
    'checkedAt': '2026-10-23T00:00:00Z',
    'issues': issues(overallIssues),
    'items': [
      for (final row in requested)
        {
          'cartItemId': row['id'],
          'productId': row['productId'],
          'productVariantId': row['productVariantId'],
          'productName': row['product']['name'],
          'variantName': row['variant']?['name'],
          'requestedQuantity': row['quantity'] ?? 1,
          'currentQuantity': row['quantity'] ?? 1,
          'currentUnitPrice': row['variant']?['price'] ?? 0,
          'availableStock': stock,
          'canCheckout': (itemIssues[row['id']] ?? []).isEmpty,
          'issues': issues(itemIssues[row['id']] ?? []),
        },
    ],
    'cartItems': cart,
  };
}
