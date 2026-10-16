import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_ad_ecommerce/service/chatroom_sse_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'chat_test_support.dart' show ChatAdapter, jsonResponse, settle;

void main() {
  test('401 stream JSON refreshes once, then a second 401 stops', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    var attempts = 0;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          attempts++;
          handler.resolve(
            Response(
              requestOptions: request,
              statusCode: 401,
              data: jsonResponse({'message': 'expired'}, status: 401),
            ),
          );
        },
      ),
    );
    var refreshes = 0;
    final statuses = <String>[];
    final service = ChatroomSseService(
      dio: dio,
      refreshToken: () async {
        refreshes++;
        return true;
      },
      onReady: (_) {},
      onEvent: (_, _) {},
      onReset: () {},
      onStatus: statuses.add,
    );
    addTearDown(() {
      service.stop();
      dio.close(force: true);
    });
    service.start();
    await settle();
    expect(attempts, 2);
    expect(refreshes, 1);
    expect(statuses.last, 'unauthorized');
  });

  test(
    'watchdog closes a silent stream and keeps its applied checkpoint',
    () async {
      final api = ChatAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = api;
      final statuses = <String>[];
      final service = ChatroomSseService(
        dio: dio,
        refreshToken: () async => false,
        onReady: (_) {},
        onEvent: (_, _) {},
        onReset: () {},
        onStatus: statuses.add,
        watchdog: const Duration(milliseconds: 30),
      );
      addTearDown(() {
        service.stop();
        dio.close(force: true);
      });
      service.start();
      await settle();
      api.event('stream.ready', {'schemaVersion': 1, 'cursor': 'head'});
      await settle();
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(statuses.last, 'reconnecting');
      expect(service.cursor, 'head');
      expect(service.ready, isFalse);
    },
  );

  test('malformed durable event resets without acknowledging its ID', () async {
    final api = ChatAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..httpClientAdapter = api;
    var resets = 0;
    final service = ChatroomSseService(
      dio: dio,
      refreshToken: () async => false,
      onReady: (_) {},
      onEvent: (_, _) {
        throw const FormatException('bad payload');
      },
      onReset: () {
        resets++;
      },
      onStatus: (_) {},
    );
    addTearDown(() {
      service.stop();
      dio.close(force: true);
    });
    service.start();
    await settle();
    api.event('stream.ready', {'schemaVersion': 1, 'cursor': 'head'});
    api.event('message.created', {'schemaVersion': 1}, id: 'bad');
    await settle();
    expect(resets, 1);
    expect(service.cursor, isNull);
  });

  test(
    'late refresh from a stopped session cannot stop a replacement stream',
    () async {
      final api = ChatAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = api;
      var requests = 0;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            requests++;
            if (requests == 1) {
              handler.resolve(
                Response(
                  requestOptions: request,
                  statusCode: 401,
                  data: jsonResponse({'message': 'expired'}, status: 401),
                ),
              );
            } else {
              handler.next(request);
            }
          },
        ),
      );
      final refresh = Completer<bool>();
      final statuses = <String>[];
      final service = ChatroomSseService(
        dio: dio,
        refreshToken: () => refresh.future,
        onReady: (_) {},
        onEvent: (_, _) {},
        onReset: () {},
        onStatus: statuses.add,
      );
      addTearDown(() {
        service.stop();
        dio.close(force: true);
      });
      service.start();
      await settle();
      service.stop(clearCursor: true);
      service.start();
      await settle();
      api.event('stream.ready', {'schemaVersion': 1, 'cursor': 'new-session'});
      await settle();
      refresh.complete(false);
      await settle();
      expect(service.ready, isTrue);
      expect(service.cursor, 'new-session');
      expect(statuses.last, 'connected');
    },
  );
}
