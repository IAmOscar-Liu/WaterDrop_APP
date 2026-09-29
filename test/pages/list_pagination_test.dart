import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/pages/chatroom_list_page.dart';
import 'package:flutter_ad_ecommerce/pages/message_page.dart';
import 'package:flutter_ad_ecommerce/pages/order_page.dart';
import 'package:flutter_ad_ecommerce/provider/dio_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visibility_detector/visibility_detector.dart';

void main() {
  for (final scenario in [
    (page: const OrderPage(), path: '/api/order/list', field: 'orders'),
    (
      page: const ChatroomListPage(),
      path: '/api/chatroom/list',
      field: 'rooms',
    ),
    (
      page: const MessagePage(),
      path: '/api/notification/list',
      field: 'notifications',
    ),
  ]) {
    testWidgets(
      '${scenario.page.runtimeType} loads the next page when its last row becomes visible',
      (tester) async {
        final previousInterval =
            VisibilityDetectorController.instance.updateInterval;
        VisibilityDetectorController.instance.updateInterval = Duration.zero;
        addTearDown(
          () => VisibilityDetectorController.instance.updateInterval =
              previousInterval,
        );
        final requestedPages = <int>[];
        final dio = Dio()
          ..interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) {
                if (options.path != scenario.path) {
                  handler.resolve(
                    Response(
                      requestOptions: options,
                      data: {
                        'success': true,
                        'data': {'total': 0},
                      },
                    ),
                  );
                  return;
                }
                final page = options.queryParameters['page'] as int;
                requestedPages.add(page);
                handler.resolve(
                  Response(
                    requestOptions: options,
                    data: {
                      'success': true,
                      'data': {
                        scenario.field: List.generate(
                          10,
                          (index) => {
                            'id': 'row-${(page - 1) * 10 + index}',
                            'title': 'Notification $index',
                            'body': 'Message body',
                            'isRead': true,
                            'createdAt': '2026-09-29T00:00:00Z',
                            'updatedAt': '2026-09-29T00:00:00Z',
                          },
                        ),
                        'total': 20,
                        'page': page,
                        'limit': 10,
                        'totalPages': 2,
                      },
                    },
                  ),
                );
              },
            ),
          );
        addTearDown(() => dio.close());
        await tester.pumpWidget(
          ProviderScope(
            overrides: [dioProvider.overrideWithValue(dio)],
            child: MaterialApp(home: scenario.page),
          ),
        );
        await tester.pumpAndSettle();
        expect(requestedPages, [1]);

        final scrollable = find.descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        );
        await tester.scrollUntilVisible(
          find.byWidgetPredicate(
            (widget) =>
                widget is Padding && widget.key == const ValueKey('row-9'),
          ),
          300,
          scrollable: scrollable,
        );
        await tester.pumpAndSettle();
        expect(requestedPages, [1, 2]);
        await tester.scrollUntilVisible(
          find.byWidgetPredicate(
            (widget) =>
                widget is Padding && widget.key == const ValueKey('row-19'),
          ),
          300,
          scrollable: scrollable,
        );
        await tester.pumpAndSettle();
        expect(requestedPages, [1, 2]);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  }
}
