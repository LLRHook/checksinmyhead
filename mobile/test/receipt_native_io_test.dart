import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:checks_frontend/services/receipt_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:checks_frontend/services/receipt_io_client.dart';
import 'package:http/http.dart' as http;

class _SendObservedClient extends http.BaseClient
    implements JoinedReceiptClient {
  final ReceiptIoClient _inner = ReceiptIoClient();
  final Completer<void> settled;

  _SendObservedClient(this.settled);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _inner.send(request).whenComplete(() {
        if (!settled.isCompleted) settled.complete();
      });

  @override
  void close() => _inner.close();

  @override
  Future<void> finish() => _inner.finish();
}

// Real loopback TCP peer: it never finishes a response until released/closed.
class WirePeer {
  final ServerSocket server;
  final sockets = <Socket>[];
  final subscriptions = <StreamSubscription<List<int>>>[];
  final received = Completer<void>();
  final headersReceived = Completer<void>();
  final disconnected = Completer<void>();
  int posts = 0;
  final bool body;
  final bool closeOnRequest;
  late StreamSubscription<Socket> accept;
  WirePeer._(this.server, this.body, this.closeOnRequest) {
    accept = server.listen((socket) {
      sockets.add(socket);
      // The peer writes a partial body while the client deliberately aborts it.
      unawaited(socket.done.then<void>((_) {}, onError: (Object _) {}));
      final buffer = <int>[];
      var sent = false;
      subscriptions.add(
        socket.listen(
          (chunk) {
            buffer.addAll(chunk);
            final text = latin1.decode(buffer);
            final end = text.indexOf('\r\n\r\n');
            if (sent || end < 0) return;
            if (!headersReceived.isCompleted) headersReceived.complete();
            final length = int.parse(
              RegExp(
                r'content-length: (\d+)',
                caseSensitive: false,
              ).firstMatch(text)!.group(1)!,
            );
            if (buffer.length < end + 4 + length) return;
            sent = true;
            if (text.startsWith('POST ')) posts++;
            if (closeOnRequest) socket.destroy();
            if (body) {
              socket.write(
                'HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n1\r\n{\r\n',
              );
            }
            if (!received.isCompleted) received.complete();
          },
          onDone: () {
            if (!disconnected.isCompleted) disconnected.complete();
          },
          onError: (Object _) {
            if (!disconnected.isCompleted) disconnected.complete();
          },
        ),
      );
    });
  }
  static Future<WirePeer> start({
    bool body = false,
    bool closeOnRequest = false,
  }) async => WirePeer._(
    await ServerSocket.bind(InternetAddress.loopbackIPv4, 0),
    body,
    closeOnRequest,
  );
  Uri get url => Uri.parse('http://127.0.0.1:${server.port}');
  Future<void> close() async {
    for (final s in sockets) {
      s.destroy();
    }
    for (final s in subscriptions) {
      await s.cancel();
    }
    await accept.cancel();
    await server.close();
  }
}

void main() {
  test('native timeout closes actual upstream connection', () async {
    final peer = await WirePeer.start();
    final dir = await Directory.systemTemp.createTemp('ocr-a2-mobile-');
    final image = await File('${dir.path}/receipt.jpg').writeAsBytes([1, 2, 3]);
    final clients = <ReceiptIoClient>[];
    final service = ReceiptApiService.forTesting(
      baseUrl: peer.url,
      createClient: () {
        final c = ReceiptIoClient();
        clients.add(c);
        return c;
      },
      timeout: const Duration(milliseconds: 100),
    );
    Object? result;
    final pending = service
        .parseReceipt(image.path)
        .then<void>(
          (_) => result = 'unexpected success',
          onError: (Object error) {
            result = error;
          },
        );
    try {
      await peer.received.future.timeout(const Duration(seconds: 2));
      await pending.timeout(
        const Duration(milliseconds: 300),
        onTimeout: () {},
      );
      final ended = await peer.disconnected.future
          .then((_) => true)
          .timeout(const Duration(milliseconds: 400), onTimeout: () => false);
      expect(
        ended,
        isTrue,
        reason:
            'timeout must terminate the real native peer, not just stop waiting',
      );
      expect(result, isA<ReceiptParseException>());
      expect(peer.posts, 1);
    } finally {
      for (final c in clients) {
        c.close();
      }
      await peer.close();
      await pending;
      await dir.delete(recursive: true);
    }
  });
  for (final phase in ['headers', 'body']) {
    for (final stop in ['timeout', 'cancel', 'dispose']) {
      test(
        'native $phase stall $stop terminates upstream and joins fixture cleanup',
        () async {
          final peer = await WirePeer.start(body: phase == 'body');
          final dir = await Directory.systemTemp.createTemp('ocr-a2-mobile-');
          final image = await File(
            '${dir.path}/receipt.jpg',
          ).writeAsBytes([1, 2, 3]);
          final service = ReceiptApiService.forTesting(
            baseUrl: peer.url,
            createClient: ReceiptIoClient.new,
            timeout:
                stop == 'timeout'
                    ? const Duration(milliseconds: 100)
                    : const Duration(seconds: 2),
          );
          try {
            final pending = service.parseReceipt(image.path);
            final assertion = expectLater(
              pending,
              throwsA(
                isA<ReceiptParseException>().having(
                  (e) => e.isCancelled,
                  'cancel reason',
                  stop != 'timeout',
                ),
              ),
            );
            await peer.received.future.timeout(const Duration(seconds: 2));
            if (stop == 'cancel') service.cancel();
            if (stop == 'dispose') service.dispose();
            await assertion;
            final ended = await peer.disconnected.future
                .then((_) => true)
                .timeout(
                  const Duration(milliseconds: 400),
                  onTimeout: () => false,
                );
            expect(ended, isTrue, reason: 'actual native work must end');
            expect(peer.posts, 1);
          } finally {
            service.dispose();
            await peer.close();
            await dir.delete(recursive: true);
          }
        },
      );
    }
  }
  for (final mode in ['cancel', 'source-error', 'cleanup-error', 'reentrant']) {
    test(
      mode == 'cancel'
          ? 'native cancellation stops a streaming upload and cancels its input subscription'
          : 'native $mode joins its input subscription cleanup',
      () async {
        final peer = await WirePeer.start();
        final cancelStarted = Completer<void>();
        final releaseCleanup = Completer<void>();
        final sendSettled = Completer<void>();
        var cleanupFinished = false;
        var cancellations = 0;
        late ReceiptApiService service;
        final input = StreamController<List<int>>(
          onListen: mode == 'reentrant' ? () => service.cancel() : null,
          onCancel: () async {
            cancellations++;
            cancelStarted.complete();
            await releaseCleanup.future;
            cleanupFinished = true;
            if (mode == 'cleanup-error') {
              throw StateError('synthetic private cleanup error');
            }
          },
        );
        service = ReceiptApiService.forTesting(
          baseUrl: peer.url,
          createClient: () => _SendObservedClient(sendSettled),
          prepareImage:
              (_) async =>
                  http.MultipartFile('image', input.stream, 1024 * 1024),
        );
        var operationSettled = false;
        Object? failure;
        final observed = service
            .parseReceipt('test-only-stream')
            .then<void>(
              (_) {
                operationSettled = true;
              },
              onError: (Object error) {
                failure = error;
                operationSettled = true;
              },
            );
        try {
          input.add(List.filled(128, 1));
          if (mode != 'reentrant') {
            await peer.headersReceived.future.timeout(
              const Duration(seconds: 2),
            );
            if (mode == 'source-error') {
              input.addError(StateError('synthetic private input error'));
            } else {
              service.cancel();
            }
          }
          await cancelStarted.future.timeout(const Duration(seconds: 2));
          // The serializer itself waits for cleanup on its source-error path.
          // The other paths expose the independently completed native send.
          if (mode != 'source-error') {
            await sendSettled.future.timeout(const Duration(seconds: 2));
          }
          // Observe completed native send and its queued continuations while
          // the original source's asynchronous cleanup remains held.
          await Future<void>.delayed(Duration.zero);
          expect(
            operationSettled,
            isFalse,
            reason:
                'native send completion must not release upload-input ownership',
          );
          releaseCleanup.complete();
          await observed.timeout(const Duration(seconds: 2));
          expect(cleanupFinished, isTrue);
          expect(cancellations, 1);
          expect(failure, isA<ReceiptParseException>());
          expect(failure.toString(), isNot(contains('synthetic private')));
          final ended = await peer.disconnected.future
              .then((_) => true)
              .timeout(
                const Duration(milliseconds: 400),
                onTimeout: () => false,
              );
          expect(ended, isTrue);
        } finally {
          if (!releaseCleanup.isCompleted) releaseCleanup.complete();
          service.dispose();
          await observed.timeout(const Duration(seconds: 2));
          await input.close();
          await peer.close();
        }
      },
    );
  }
  for (final code in [302, 303, 307]) {
    test(
      'native $code never follows Location and counts only one wire POST',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final methods = <String>[];
        final paths = <String>[];
        final handlers = <Future<void>>[];
        final accept = server.listen((request) {
          handlers.add(() async {
            methods.add(request.method);
            paths.add(request.uri.path);
            await request.drain<void>();
            request.response.statusCode = code;
            request.response.headers.set(
              'location',
              'http://127.0.0.1:${server.port}/forbidden',
            );
            request.response.contentLength = 0;
            await request.response.close();
          }());
        });
        final service = ReceiptApiService.forTesting(
          baseUrl: Uri.parse('http://127.0.0.1:${server.port}'),
          createClient: ReceiptIoClient.new,
          prepareImage: (_) async => http.MultipartFile.fromBytes('image', [1]),
        );
        try {
          await expectLater(
            service.parseReceipt('fixture'),
            throwsA(isA<ReceiptParseException>()),
          );
          expect(methods, ['POST']);
          expect(paths, ['/api/receipts/parse']);
        } finally {
          service.dispose();
          await accept.cancel();
          await server.close(force: true);
          await Future.wait(handlers);
        }
      },
    );
  }
  test(
    'native failed POST is never retried and a deliberate manual retry sends one new POST',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final methods = <String>[];
      final handlers = <Future<void>>[];
      final accept = server.listen((request) {
        handlers.add(() async {
          methods.add(request.method);
          await request.drain<void>();
          request.response.statusCode = methods.length == 1 ? 503 : 200;
          request.response.write('{"items":[]}');
          await request.response.close();
        }());
      });
      final clients = <ReceiptIoClient>[];
      final service = ReceiptApiService.forTesting(
        baseUrl: Uri.parse('http://127.0.0.1:${server.port}'),
        createClient: () {
          final client = ReceiptIoClient();
          clients.add(client);
          return client;
        },
        prepareImage: (_) async => http.MultipartFile.fromBytes('image', [1]),
      );
      try {
        await expectLater(
          service.parseReceipt('fixture'),
          throwsA(isA<ReceiptParseException>()),
        );
        expect(methods, ['POST']);
        expect((await service.parseReceipt('fixture')).items, isEmpty);
        expect(methods, ['POST', 'POST']);
        expect(clients.length, 2);
        for (final client in clients) {
          await expectLater(
            client.send(
              http.Request('GET', Uri.parse('http://127.0.0.1:${server.port}')),
            ),
            throwsA(isA<http.ClientException>()),
          );
        }
        expect(methods.length, 2);
      } finally {
        service.dispose();
        await accept.cancel();
        await server.close(force: true);
        await Future.wait(handlers);
      }
    },
  );
  test(
    'native compressed response enforces decoded 1MiB and closes stream',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final handlers = <Future<void>>[];
      final compressed = gzip.encode(List.filled(1024 * 1024 + 1, 32));
      final accept = server.listen((request) {
        handlers.add(() async {
          await request.drain<void>();
          request.response.headers.set('content-encoding', 'gzip');
          request.response.contentLength = compressed.length;
          request.response.add(compressed);
          await request.response.close();
        }());
      });
      final service = ReceiptApiService.forTesting(
        baseUrl: Uri.parse('http://127.0.0.1:${server.port}'),
        createClient: ReceiptIoClient.new,
        prepareImage: (_) async => http.MultipartFile.fromBytes('image', [1]),
      );
      try {
        await expectLater(
          service.parseReceipt('fixture'),
          throwsA(
            isA<ReceiptParseException>().having(
              (e) => e.message,
              'size',
              contains('invalid or too large'),
            ),
          ),
        );
      } finally {
        service.dispose();
        await accept.cancel();
        await server.close(force: true);
        await Future.wait(handlers);
      }
    },
  );
  test('native dropped response after upload never replays a POST', () async {
    final peer = await WirePeer.start(closeOnRequest: true);
    final service = ReceiptApiService.forTesting(
      baseUrl: peer.url,
      createClient: ReceiptIoClient.new,
      prepareImage: (_) async => http.MultipartFile.fromBytes('image', [1]),
    );
    try {
      await expectLater(
        service.parseReceipt('fixture'),
        throwsA(isA<ReceiptParseException>()),
      );
      expect(peer.posts, 1);
      expect(peer.sockets.length, 1);
    } finally {
      service.dispose();
      await peer.close();
    }
  });
}
