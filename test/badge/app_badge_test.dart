import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_ad_ecommerce/models/app_badge.dart';
import 'package:flutter_ad_ecommerce/provider/app_badge_provider.dart';
import 'package:flutter_ad_ecommerce/provider/session_logout_provider.dart';
import 'package:flutter_ad_ecommerce/service/app_badge_service.dart';
import 'package:flutter_ad_ecommerce/service/notification_tap_service.dart';
import 'package:flutter_ad_ecommerce/utils/events.dart';
import 'package:flutter_ad_ecommerce/utils/result.dart';
import 'package:flutter_ad_ecommerce/utils/device_info.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> badge({
  int version = 1,
  int boxes = 2,
  int notifications = 3,
  int chats = 4,
  DateTime? deadline,
}) => {
  'version': version,
  'total': boxes + notifications + chats,
  'claimableUnopenedBoxes': boxes,
  'unreadNotifications': notifications,
  'unreadChatMessages': chats,
  'nextReconcileAt': deadline?.toUtc().toIso8601String(),
};

class Harness {
  Harness() {
    controller = AppBadgeController(dio, (count) async {
      writes.add(count);
    }, now: () => now);
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          requests.add(request);
          if (hold) {
            held.add(
              () => handler.resolve(
                Response(
                  requestOptions: request,
                  statusCode: 200,
                  data: {'success': true, 'data': value},
                ),
              ),
            );
          } else {
            handler.resolve(
              Response(
                requestOptions: request,
                statusCode: 200,
                data: {'success': !fail, 'data': value},
              ),
            );
          }
        },
      ),
    );
  }
  final dio = Dio();
  late final AppBadgeController controller;
  final writes = <int>[];
  final requests = <RequestOptions>[];
  final held = <void Function()>[];
  DateTime now = DateTime.utc(2026, 10, 20);
  Map<String, dynamic> value = badge();
  bool hold = false, fail = false;
  Future<void> tick(
    WidgetTester tester, [
    Duration duration = const Duration(milliseconds: 250),
  ]) async {
    now = now.add(duration);
    await tester.pump(duration);
    await tester.pump();
  }

  void dispose() {
    controller.dispose();
    dio.close(force: true);
  }
}

void main() {
  test('snapshot validates counts, sum and UTC deadline', () {
    expect(AppBadge.fromJson(badge()).total, 9);
    for (final invalid in [
      {...badge(), 'total': -1},
      {...badge(), 'total': 10},
      {...badge(), 'version': 0},
      {...badge(), 'unreadNotifications': '3'},
      {...badge(), 'nextReconcileAt': 'invalid'},
      {...badge(), 'nextReconcileAt': '2026-10-20T12:00:00'},
      {...badge()}..remove('claimableUnopenedBoxes'),
    ]) {
      expect(() => AppBadge.fromJson(invalid), throwsFormatException);
    }
  });

  testWidgets(
    'boot, coalescing and in-flight invalidation use complete REST snapshots',
    (tester) async {
      final h = Harness();
      addTearDown(h.dispose);
      h.controller.configureSession('a', foreground: true);
      h.controller.invalidate();
      h.controller.invalidate();
      await h.tick(tester);
      expect(h.requests, hasLength(1));
      expect(h.requests.single.path, '/api/app/badge');
      expect(h.requests.single.queryParameters, isEmpty);
      expect(h.writes, [9]);
      h.hold = true;
      h.controller.invalidate();
      await h.tick(tester);
      h.controller.invalidate();
      h.controller.invalidate();
      await h.tick(tester);
      expect(h.requests, hasLength(2));
      h.value = badge(version: 2, boxes: 0);
      h.held.removeAt(0)();
      await tester.pump();
      h.hold = false;
      await h.tick(tester);
      expect(h.requests, hasLength(3));
      expect(h.controller.snapshot!.total, 7);
    },
  );

  testWidgets('errors, partial and older snapshots preserve confirmed count', (
    tester,
  ) async {
    final h = Harness();
    addTearDown(h.dispose);
    h.value = badge(version: 5);
    h.controller.configureSession('a', foreground: true);
    await h.tick(tester);
    for (final value in [
      badge(version: 4, boxes: 0),
      {'version': 6},
      {...badge(version: 7), 'total': -1},
    ]) {
      h.value = value;
      h.controller.invalidate();
      await h.tick(tester);
      expect(h.controller.snapshot!.version, 5);
      expect(h.writes, [9]);
    }
    h.fail = true;
    h.controller.invalidate();
    await h.tick(tester);
    expect(h.writes, [9]);
    expect(h.controller.error, isNotNull);
    h.fail = false;
    h.value = badge(version: 6, boxes: 0, notifications: 0, chats: 0);
    h.controller.invalidate();
    await h.tick(tester);
    expect(h.writes.last, 0);
  });

  testWidgets('equal-version REST changes re-arm deadline; skew is bounded', (
    tester,
  ) async {
    final h = Harness();
    addTearDown(h.dispose);
    h.value = badge(deadline: h.now.add(const Duration(hours: 2)));
    h.controller.configureSession('a', foreground: true);
    await h.tick(tester);
    final earlier = h.now.add(const Duration(minutes: 1));
    h.value = badge(deadline: earlier);
    h.controller.invalidate();
    await h.tick(tester);
    expect(h.controller.snapshot!.nextReconcileAt, earlier);
    await h.tick(tester, const Duration(minutes: 1));
    await h.tick(tester);
    expect(h.requests, hasLength(3));
    // The same now-past server deadline must not start an immediate retry loop.
    await h.tick(tester, const Duration(seconds: 1));
    expect(h.requests, hasLength(3));
    await h.tick(tester, const Duration(seconds: 30));
    await h.tick(tester);
    expect(h.requests, hasLength(4));
    h.controller.configureSession('a', foreground: false);
  });

  testWidgets(
    'background cancels timer/request, resume reconciles and logout clears',
    (tester) async {
      final h = Harness();
      addTearDown(h.dispose);
      h.value = badge(deadline: h.now.add(const Duration(minutes: 1)));
      h.controller.configureSession('a', foreground: true);
      await h.tick(tester);
      h.controller.configureSession('a', foreground: false);
      h.controller.invalidate();
      await h.tick(tester, const Duration(minutes: 2));
      expect(h.requests, hasLength(1));
      expect(h.writes, [9]);
      h.controller.configureSession('a', foreground: true);
      await h.tick(tester);
      expect(h.requests, hasLength(2));
      h.controller.configureSession(null, foreground: false);
      await tester.pump();
      expect(h.writes.last, 0);
      expect(h.controller.snapshot, isNull);
      await h.tick(tester, const Duration(minutes: 2));
      expect(h.requests, hasLength(2));
    },
  );

  testWidgets(
    'account switch ignores late response and accepts a lower new-user revision',
    (tester) async {
      final h = Harness();
      addTearDown(h.dispose);
      h.hold = true;
      h.controller.configureSession('a', foreground: true);
      await h.tick(tester);
      h.controller.configureSession('b', foreground: true);
      h.value = badge(version: 99);
      h.held.removeAt(0)();
      await tester.pump();
      expect(h.controller.snapshot, isNull);
      h.hold = false;
      h.value = badge(version: 1, boxes: 0);
      await h.tick(tester);
      expect(h.controller.snapshot!.version, 1);
      expect(h.writes.last, 7);
    },
  );

  testWidgets(
    'push metadata only invalidates current-user counts; badge_sync cannot navigate',
    (tester) async {
      final h = Harness();
      addTearDown(h.dispose);
      h.controller.configureSession('a', foreground: true);
      await h.tick(tester);
      final data = {
        'command': 'badge_sync',
        'badgeUserId': 'a',
        'badgeVersion': '2',
        'badgeTotal': '99',
      };
      expect(h.controller.handlePush({...data, 'badgeUserId': 'b'}), isFalse);
      expect(h.controller.handlePush({...data, 'badgeVersion': '0'}), isFalse);
      expect(h.controller.handlePush(data), isTrue);
      expect(h.controller.snapshot!.total, 9);
      pendingNotificationTap.value = null;
      queueNotificationTap(NotificationTappedEvent(data: data));
      expect(pendingNotificationTap.value, isNull);
      h.value = badge(version: 2, boxes: 3);
      await h.tick(tester);
      expect(h.controller.snapshot!.total, 10);
      expect(h.writes.last, 10);
    },
  );

  test(
    'registration drains before logout and prevents late registrations',
    () async {
      final order = <String>[];
      final pending = Completer<Result<String>>();
      final registration = DeviceRegistration(
        owner: () => 'a',
        registerToken: (_) {
          order.add('register');
          return pending.future;
        },
        removeToken: () async {
          order.add('remove');
          return Result.success(true);
        },
      );
      final registering = registration.register('token');
      await Future<void>.delayed(Duration.zero);
      final logout = registration.unregister();
      await registration.register('late-token');
      expect(order, ['register']);
      pending.complete(Result.success('token'));
      await registering;
      await logout;
      expect(order, ['register', 'remove']);
    },
  );

  test(
    'failed token deregistration keeps authentication for a retry',
    () async {
      var signedOut = false;
      final registration = DeviceRegistration(
        owner: () => 'a',
        registerToken: (_) async => Result.success('token'),
        removeToken: () async => Result.failure('offline'),
      );
      final container = ProviderContainer(
        overrides: [
          deviceRegistrationProvider.overrideWithValue(registration),
          firebaseSignOutProvider.overrideWithValue(() async {
            signedOut = true;
          }),
        ],
      );
      addTearDown(container.dispose);
      final result = await container.read(sessionLogoutProvider)();
      expect(result.isFailure, isTrue);
      expect(signedOut, isFalse);
      expect(registration.signingOut, isFalse);
    },
  );

  testWidgets('logout removes token before sign-out and clears aggregate', (
    tester,
  ) async {
    final h = Harness();
    final order = <String>[];
    final registration = DeviceRegistration(
      owner: () => 'a',
      registerToken: (_) async => Result.success('token'),
      removeToken: () async {
        order.add('remove');
        return Result.success(true);
      },
    );
    final container = ProviderContainer(
      overrides: [
        deviceRegistrationProvider.overrideWithValue(registration),
        firebaseSignOutProvider.overrideWithValue(() async {
          order.add('signOut');
        }),
        appBadgeProvider.overrideWith((ref) => h.controller),
      ],
    );
    h.controller.configureSession('a', foreground: true);
    await h.tick(tester);
    final logout = container.read(sessionLogoutProvider)();
    await tester.pump();
    expect((await logout).isSuccess, isTrue);
    await tester.pump();
    expect(order, ['remove', 'signOut']);
    expect(h.writes.last, 0);
    expect(h.controller.snapshot, isNull);
    container.dispose();
    h.dio.close(force: true);
  });

  testWidgets(
    'queued native writes finish with new account count after switching',
    (tester) async {
      final h = Harness();
      final pending = Completer<void>();
      final writes = <int>[];
      final controller = AppBadgeController(h.dio, (count) async {
        writes.add(count);
        if (writes.length == 1) await pending.future;
      });
      controller.configureSession('a', foreground: true);
      await h.tick(tester);
      controller.configureSession(null, foreground: false);
      controller.configureSession('b', foreground: true);
      h.value = badge(boxes: 0);
      await h.tick(tester);
      pending.complete();
      await tester.pump();
      expect(writes, [9, 0, 7]);
      controller.dispose();
      h.dispose();
    },
  );

  test('installation ID survives repeated and concurrent reads', () async {
    SharedPreferences.setMockInitialValues({});
    final ids = await Future.wait([getDeviceId(), getDeviceId()]);
    expect(ids.first, ids.last);
    expect(
      ids.first,
      (await SharedPreferences.getInstance()).getString('pushInstallationId'),
    );
  });

  testWidgets(
    'iOS writes absolute native count; Android creates no notification',
    (tester) async {
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        AppBadgeService.channel,
        (call) async {
          calls.add(call);
          return null;
        },
      );
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          AppBadgeService.channel,
          null,
        );
      });
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await AppBadgeService().setCount(9);
      await AppBadgeService().setCount(0);
      expect(calls.map((c) => c.arguments), [
        {'count': 9},
        {'count': 0},
      ]);
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await AppBadgeService().setCount(5);
      expect(calls, hasLength(2));
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
