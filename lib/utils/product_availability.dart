import 'package:dio/dio.dart';

import 'exception_handler.dart';

const productUnavailableMessage = '商品或所選規格已下架或不存在，資料已重新整理，請重新確認。';

bool isProductAvailabilityError(DioException error) {
  if (error.response?.statusCode != 400 && error.response?.statusCode != 404) {
    return false;
  }
  return const {
    'Product is unavailable',
    'Product variant is inactive',
    'Product not found',
    'Product variant not found',
    'Cart item not found',
  }.contains(getDioExceptionMessage(error));
}

String productMutationErrorMessage(DioException error) =>
    isProductAvailabilityError(error)
    ? productUnavailableMessage
    : getDioExceptionMessage(error);

String orderItemReasonText(String reason) => switch (reason) {
  'Not found' || 'Product not found' => '商品已下架或不存在',
  'Product deleted' => '商品已刪除',
  'Product inactive' => '商品已下架',
  'Variant not found' => '所選規格已下架或不存在',
  'Variant inactive' => '所選規格已下架',
  'Insufficient stock' => '庫存不足',
  _ => reason,
};
