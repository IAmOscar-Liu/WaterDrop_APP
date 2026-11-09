import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_ad_ecommerce/provider/collection_provider.dart';
import 'package:flutter_ad_ecommerce/provider/dio_provider.dart';
import 'package:flutter_ad_ecommerce/provider/message_provider.dart';
import 'package:flutter_ad_ecommerce/provider/product_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../chat/chat_test_support.dart';

void main() {
  for (final kind in ['products', 'collections', 'notifications']) {
    for (final oldFailure in [false, true]) {
      for (final pagination in [false, true]) {
        test(
          '$kind ignores stale ${pagination ? 'page' : 'query'} ${oldFailure ? 'errors' : 'results'} after switching filters',
          () async {
            final api = ChatAdapter();
            final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
              ..httpClientAdapter = api;
            final container = ProviderContainer(
              overrides: [dioProvider.overrideWithValue(dio)],
            );
            addTearDown(() {
              container.dispose();
              dio.close(force: true);
            });
            late Future<void> Function(String) load;
            late Future<void> Function() more;
            late List<String> Function() ids;
            if (kind == 'products') {
              container.listen(productNotifierProvider, (_, _) {});
              final notifier = container.read(productNotifierProvider.notifier);
              load = (filter) => notifier.loadProducts(categoryId: filter);
              more = notifier.fetchMoreProducts;
              ids = () => container
                  .read(productNotifierProvider)
                  .data!
                  .products
                  .map((p) => p.id)
                  .toList();
            } else if (kind == 'collections') {
              container.listen(collectionNotifierProvider, (_, _) {});
              final notifier = container.read(
                collectionNotifierProvider.notifier,
              );
              load = (filter) => notifier.loadCollections(search: filter);
              more = notifier.fetchMoreCollections;
              ids = () => container
                  .read(collectionNotifierProvider)
                  .data!
                  .collections
                  .map((p) => p.id)
                  .toList();
            } else {
              container.listen(messageNotifierProvider, (_, _) {});
              final notifier = container.read(messageNotifierProvider.notifier);
              load = (filter) => notifier.loadMessages(search: filter);
              more = notifier.fetchMoreMessages;
              ids = () => container
                  .read(messageNotifierProvider)
                  .data!
                  .messages
                  .map((p) => p.id)
                  .toList();
            }
            ResponseBody response(String id, {int page = 1}) => jsonResponse({
              kind: [
                {
                  'id': id,
                  'product': {'id': id},
                },
              ],
              'page': page,
              'limit': 20,
              'total': 2,
              'totalPages': 2,
            });
            final old = Completer<ResponseBody>();
            final latest = Completer<ResponseBody>();
            api.handler = (r) async {
              final filter =
                  r.queryParameters['categoryId'] ??
                  r.queryParameters['search'];
              if (filter == 'B') return latest.future;
              if (pagination && r.queryParameters['page'] == 1) {
                return response('A');
              }
              return old.future;
            };
            Future<void> outdated;
            if (pagination) {
              await load('A');
              outdated = more();
            } else {
              outdated = load('A');
            }
            await settle();
            final current = load('B');
            await settle();
            latest.complete(response('B'));
            await current;
            expect(ids(), ['B']);
            old.complete(
              oldFailure
                  ? jsonResponse({'message': 'old error'}, status: 503)
                  : response('A-late', page: pagination ? 2 : 1),
            );
            await outdated;
            expect(ids(), ['B']);
          },
        );
      }
    }
  }
}
