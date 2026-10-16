import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_ad_ecommerce/constants/app_constants.dart';
import 'package:flutter_ad_ecommerce/provider/chat_sync_provider.dart';
import 'package:flutter_ad_ecommerce/provider/chatroom_list_provider.dart';
import 'package:flutter_ad_ecommerce/provider/dio_provider.dart';
import 'package:flutter_ad_ecommerce/provider/order_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../chat/chat_test_support.dart';

void main() {
  for (final scenario in [
    'success',
    'failed-order',
    'failed-refresh',
    'reconnecting',
    'loading',
  ]) {
    test('order creation refreshes chat metadata: $scenario', () async {
      final api = ChatAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = api;
      final sync = ChatSyncController(dio, () async => false);
      final container = ProviderContainer(
        overrides: [
          dioProvider.overrideWithValue(dio),
          chatSyncProvider.overrideWith((ref) => sync),
        ],
      );
      addTearDown(() {
        container.dispose();
        if (!AppConstants.chatSseEnabled) sync.dispose();
        dio.close(force: true);
      });
      final requestedPages = <int>[];
      var created = false;
      var hold = false;
      final inFlight = Completer<ResponseBody>();
      Map<String, dynamic> roomsFor(int page, bool updated) => listResponse(
        [
          {
            ...room('room-$page'),
            'order': {
              'id': updated ? 'new-order' : 'old-order',
              'orderStatus': updated ? 'payment_processing' : 'pending',
              'delivery': {'RtnMsg': updated ? '訂單處理中(賣家已收到訂單資料)' : '尚未成立'},
            },
          },
        ],
        page: page,
        pages: 2,
      );
      api.handler = (r) async {
        if (r.method == 'POST' && r.path == '/api/order') {
          if (scenario == 'failed-order') {
            return jsonResponse({'message': 'Failed'}, status: 503);
          }
          created = true;
          return jsonResponse({'id': 'new-order'});
        }
        final page = r.queryParameters['page'] as int;
        requestedPages.add(page);
        if (hold) {
          hold = false;
          return inFlight.future;
        }
        if (created && scenario == 'failed-refresh') {
          return jsonResponse({'message': 'Offline'}, status: 503);
        }
        return jsonResponse(roomsFor(page, created));
      };
      if (AppConstants.chatSseEnabled) {
        // Instantiate the override so the container owns controller disposal.
        container.read(chatSyncProvider);
        sync.configureSession('u', foreground: true);
        await settle();
        api.event('stream.ready', {'schemaVersion': 1, 'cursor': 'head'});
        await settle();
        await sync.loadList(more: true);
      }
      requestedPages.clear();
      if (scenario == 'reconnecting' && AppConstants.chatSseEnabled) {
        sync.configureSession('u', foreground: false);
        await settle();
      }
      Future<void>? loading;
      if (scenario == 'loading' && AppConstants.chatSseEnabled) {
        hold = true;
        loading = sync.loadList();
        await settle();
      }
      final result = await container
          .read(orderNotifierProvider.notifier)
          .createOrder(
            idempotencyKey: 'key',
            subTotal: 100,
            totalAmount: 100,
            discountCoin: 0,
            shippingCost: 0,
            shippingCostDeduction: 0,
            transactionFee: 0,
            cartItems: [],
            shippingInfo: {},
          );
      expect(result.isSuccess, scenario != 'failed-order');
      if (loading != null) {
        // Order success must not wait for an unrelated metadata request.
        expect(requestedPages, [1]);
        inFlight.complete(jsonResponse(roomsFor(1, false)));
        await loading;
      }
      if (scenario == 'reconnecting' && AppConstants.chatSseEnabled) {
        expect(requestedPages, isEmpty);
        sync.configureSession('u', foreground: true);
        await settle();
        api.event('stream.ready', {'schemaVersion': 1, 'cursor': 'head'});
      }
      await settle();
      if (scenario == 'failed-order') {
        expect(requestedPages, isEmpty);
      } else if (scenario == 'failed-refresh') {
        expect(requestedPages, [1]);
      } else if (AppConstants.chatSseEnabled) {
        expect(requestedPages.first, 1);
        expect(sync.rooms.first.order!.id, 'new-order');
        expect(sync.rooms.first.order!.delivery!.rtnMsg, '訂單處理中(賣家已收到訂單資料)');
        expect(requestedPages, scenario == 'loading' ? [1, 1, 2] : [1, 2]);
        expect(sync.rooms.every((r) => r.order!.id == 'new-order'), isTrue);
        expect(sync.hasMoreRooms, isFalse);
        expect(api.connections.length, scenario == 'reconnecting' ? 2 : 1);
      } else {
        expect(requestedPages, [1]);
        expect(
          container
              .read(chatroomListNotifierProvider)
              .data!
              .rooms
              .first
              .order!
              .id,
          'new-order',
        );
      }
    });
  }
}
