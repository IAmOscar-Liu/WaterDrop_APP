import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/constants/app_constants.dart';
import 'package:flutter_ad_ecommerce/pages/chatroom_list_page.dart';
import 'package:flutter_ad_ecommerce/pages/sync_chatroom_page.dart';
import 'package:flutter_ad_ecommerce/provider/chat_sync_provider.dart';
import 'package:flutter_ad_ecommerce/provider/dio_provider.dart';
import 'package:flutter_ad_ecommerce/router/routes.dart';
import 'package:flutter_ad_ecommerce/router/chat_route_observer.dart';
import 'package:flutter_ad_ecommerce/shared/widgets/simple_app_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'chat_test_support.dart';

void main() {
  for (final nested in [false, true]) {
    testWidgets(
      'list to chat preserves variant with sparse metadata (nested=$nested)',
      (tester) async {
        final api = ChatAdapter();
        final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
          ..httpClientAdapter = api;
        final sync = ChatSyncController(dio, () async => false);
        api.handler = (r) async {
          if (r.path.endsWith('/list')) {
            return jsonResponse(
              listResponse([
                {
                  ...room('a'),
                  'accountId': 'seller',
                  'product': {
                    'name': '行動電源',
                    if (!nested) 'variantName': '白色 / 小',
                  },
                  if (nested) 'variant': {'id': 'v', 'name': '白色 / 小'},
                },
              ]),
            );
          }
          if (r.path.contains('/history/')) {
            return jsonResponse(historyResponse([]));
          }
          // Detail metadata can omit the variant even though the list includes it.
          return jsonResponse({
            ...room('a'),
            'accountId': 'seller',
            'product': {'name': '行動電源', 'variantName': ''},
          });
        };
        final router = GoRouter(
          observers: [chatRouteObserver],
          routes: [
            GoRoute(path: '/', builder: (_, _) => const ChatroomListPage()),
            GoRoute(
              path: Routes.chatroomPage,
              builder: (_, s) => SyncChatroomPage(extra: s.extra),
            ),
          ],
        );
        sync.configureSession('u', foreground: true);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              dioProvider.overrideWithValue(dio),
              chatSyncProvider.overrideWith((ref) => sync),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        for (var i = 0; i < 10 && api.connections.isEmpty; i++) {
          await tester.pump(const Duration(milliseconds: 1));
        }
        api.event('stream.ready', {'schemaVersion': 1, 'cursor': 'head'});
        await tester.pumpAndSettle();
        expect(find.text('白色 / 小'), findsOneWidget);
        await tester.tap(find.text('行動電源'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<SimpleAppBar>(find.byType(SimpleAppBar)).subtitle,
          '白色 / 小',
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        router.dispose();
        dio.close(force: true);
      },
      skip: !AppConstants.chatSseEnabled,
    );
  }
}
