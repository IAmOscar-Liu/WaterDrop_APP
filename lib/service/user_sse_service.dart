import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';

/// One complete SSE frame. IDs are deliberately opaque and never compared.
class UserSseFrame {
  const UserSseFrame(this.event, this.data, this.id, this.retry);
  final String event;
  final String data;
  final String? id;
  final int? retry;
}

/// LineSplitter handles CR/LF across chunks; utf8.decoder retains partial codepoints.
/// Never dispatch a truncated frame at EOF or retain an inherited durable ID on
/// a control event. A checkpoint belongs only to an explicitly identified frame.
Stream<UserSseFrame> decodeUserSse(Stream<List<int>> bytes) async* {
  var event = 'message';
  String? id;
  int? retry;
  final data = <String>[];
  var size = 0;
  var first = true;
  await for (var line
      in bytes.transform(utf8.decoder).transform(const LineSplitter())) {
    if (first) {
      line = line.replaceFirst(RegExp('^\uFEFF'), '');
      first = false;
    }
    size += line.length;
    if (size > 1024 * 1024) throw const FormatException('SSE frame too large');
    if (line.isEmpty) {
      if (data.isNotEmpty || retry != null) {
        yield UserSseFrame(event, data.join('\n'), id, retry);
      }
      event = 'message';
      id = null;
      retry = null;
      data.clear();
      size = 0;
      continue;
    }
    if (line.startsWith(':')) continue;
    final colon = line.indexOf(':');
    final field = colon < 0 ? line : line.substring(0, colon);
    var value = colon < 0 ? '' : line.substring(colon + 1);
    if (value.startsWith(' ')) value = value.substring(1);
    switch (field) {
      case 'event':
        event = value;
      case 'data':
        data.add(value);
      case 'id':
        if (!value.contains('\u0000')) id = value;
      case 'retry':
        if (RegExp(r'^\d+$').hasMatch(value)) retry = int.tryParse(value);
    }
  }
}

class _ResetStream implements Exception {
  const _ResetStream();
}

/// Owns one cancellable connection. REST uses ordinary JSON Dio requests;
/// this transport decodes pre-stream JSON errors separately from stream bytes.
class UserSseService {
  UserSseService({
    required this.dio,
    required this.path,
    required this.cursorInvalidCode,
    required this.refreshToken,
    required this.onReady,
    required this.onEvent,
    required this.onReset,
    required this.onStatus,
    this.watchdog = const Duration(seconds: 45),
  });
  final Dio dio;
  final String path;
  final String cursorInvalidCode;
  final Future<bool> Function() refreshToken;
  final void Function(bool fresh) onReady;
  final void Function(String type, Map<String, dynamic> data) onEvent;
  final void Function() onReset;
  final void Function(String status) onStatus;
  final Duration watchdog;
  String? cursor;
  bool ready = false;
  int _generation = 0;
  bool _running = false;
  CancelToken? _cancel;
  Timer? _watchdog;
  Timer? _retryTimer;
  Completer<void>? _retryWait;
  int _serverRetry = 3000;

  void start() {
    if (_running) return;
    _running = true;
    unawaited(_run(++_generation));
  }

  void stop({bool clearCursor = false}) {
    _running = false;
    ++_generation;
    ready = false;
    _cancel?.cancel();
    _watchdog?.cancel();
    _retryTimer?.cancel();
    if (!(_retryWait?.isCompleted ?? true)) _retryWait!.complete();
    if (clearCursor) cursor = null;
  }

  void _touch() {
    _watchdog?.cancel();
    _watchdog = Timer(watchdog, () => _cancel?.cancel('heartbeat timeout'));
  }

  Future<void> _delay(int ms) async {
    final wait = Completer<void>();
    _retryWait = wait;
    _retryTimer = Timer(Duration(milliseconds: ms), wait.complete);
    await wait.future;
  }

  Future<void> _run(int generation) async {
    var failures = 0;
    var authAttempted = false;
    DateTime? authenticatedAt;
    while (_running && generation == _generation) {
      if (authenticatedAt != null &&
          DateTime.now().difference(authenticatedAt) >
              const Duration(seconds: 30)) {
        authAttempted = false;
        failures = 0;
      }
      var delay = max(_serverRetry, min(30000, 1000 * (1 << min(failures, 5))));
      final cancel = _cancel = CancelToken();
      ready = false;
      onStatus('connecting');
      try {
        _touch();
        final response = await dio.get<ResponseBody>(
          path,
          cancelToken: cancel,
          options: Options(
            responseType: ResponseType.stream,
            receiveTimeout: Duration.zero,
            // Stream auth is coordinated here, including auth_expired controls.
            extra: {'skipAuthRefresh': true},
            validateStatus: (status) => status != null,
            headers: {
              'Accept': 'text/event-stream',
              if (cursor != null) 'Last-Event-ID': cursor,
            },
          ),
        );
        if (!_running || generation != _generation) break;
        final status = response.statusCode ?? 0;
        if (status != 200) {
          final body = StringBuffer();
          await for (final part
              in response.data!.stream.cast<List<int>>().transform(
                utf8.decoder,
              )) {
            body.write(part);
            if (body.length > 1024 * 1024) {
              throw const FormatException('Error response too large');
            }
          }
          Map<String, dynamic> error = {};
          try {
            error = Map<String, dynamic>.from(
              jsonDecode(body.toString()) as Map,
            );
          } catch (_) {}
          if (!_running || generation != _generation) break;
          final code = error['code'];
          if (status == 401 && !authAttempted) {
            authAttempted = true;
            final refreshed = await refreshToken();
            if (!_running || generation != _generation) break;
            if (refreshed) continue;
          }
          if (status == 401 || status == 403) {
            onStatus('unauthorized');
            _running = false;
            break;
          }
          if (status == 400 && code == cursorInvalidCode || status == 410) {
            cursor = null;
            onReset();
          } else if (status == 429) {
            final retry = response.headers.value('retry-after');
            delay = max(delay, (int.tryParse(retry ?? '') ?? 15) * 1000);
          } else if (status >= 400 && status < 500) {
            onStatus('unavailable');
            _running = false;
            break;
          }
        } else {
          if (!(response.headers.value('content-type') ?? '').contains(
            'text/event-stream',
          )) {
            throw const FormatException('Expected event stream');
          }
          var receivedReady = false;
          final bytes = response.data!.stream.map<List<int>>((chunk) {
            if (generation == _generation) _touch();
            return chunk;
          });
          await for (final frame in decodeUserSse(bytes)) {
            if (!_running || generation != _generation) break;
            if (frame.retry != null) {
              _serverRetry = frame.retry!.clamp(1000, 300000);
            }
            if (frame.data.isEmpty) continue;
            final data = Map<String, dynamic>.from(
              jsonDecode(frame.data) as Map,
            );
            if (frame.event == 'stream.reset') {
              if (data['reason'] == 'auth_expired') {
                if (authenticatedAt != null &&
                    DateTime.now().difference(authenticatedAt) >
                        const Duration(seconds: 30)) {
                  authAttempted = false;
                }
                final refreshed = !authAttempted && await refreshToken();
                if (!_running || generation != _generation) break;
                if (!refreshed) {
                  onStatus('unauthorized');
                  _running = false;
                  break;
                }
                authAttempted = true;
              }
              throw const _ResetStream();
            }
            if (data['schemaVersion'] != 1) {
              throw const FormatException('Unsupported stream schema');
            }
            if (frame.event == 'stream.ready') {
              final boundary = data['cursor'];
              if (receivedReady ||
                  boundary is! String ||
                  boundary.isEmpty ||
                  (cursor != null && boundary != cursor)) {
                throw const FormatException('Invalid ready boundary');
              }
              final fresh = cursor == null;
              cursor ??= boundary;
              receivedReady = true;
              ready = true;
              authenticatedAt = DateTime.now();
              onStatus('connected');
              onReady(fresh);
            } else {
              if (!receivedReady || frame.id == null || frame.id!.isEmpty) {
                throw const FormatException('Missing event checkpoint');
              }
              try {
                onEvent(frame.event, data);
              } catch (_) {
                throw const FormatException('Invalid stream event payload');
              }
              // Reducers must succeed before acknowledging this event.
              cursor = frame.id;
              authAttempted = false;
              failures = 0;
            }
          }
        }
      } on _ResetStream {
        if (generation == _generation) {
          cursor = null;
          onReset();
        }
      } on FormatException {
        if (generation == _generation) {
          cursor = null;
          onReset();
        }
      } catch (_) {
        // EOF/network/watchdog errors retain matching caches and checkpoint.
      } finally {
        cancel.cancel();
        if (generation == _generation) {
          _watchdog?.cancel();
          ready = false;
        }
      }
      if (!_running || generation != _generation) break;
      onStatus('reconnecting');
      failures++;
      await _delay(delay + Random().nextInt(500));
    }
  }
}
