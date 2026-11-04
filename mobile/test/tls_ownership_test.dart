import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:checks_frontend/services/receipt_api_service.dart';
import 'package:checks_frontend/services/receipt_io_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'fixtures/receipt_tls_fixture.dart';

const budget = Duration(seconds: 3);
late ReceiptTlsFixture fixture;

// Test-only observation at the actual SDK/http seam, preserving the join capability.
class ObservedTransport extends http.BaseClient implements JoinedReceiptClient {
  final ReceiptIoClient inner;
  Object? transportError;
  ObservedTransport(this.inner);
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    try {
      return await inner.send(request);
    } catch (error) {
      transportError = error;
      rethrow;
    }
  }

  @override
  void close() => inner.close();
  @override
  Future<void> finish() => inner.finish();
}

class SilentPeer {
  final ServerSocket listener;
  final hello = Completer<void>();
  final connected = Completer<void>();
  final disconnected = Completer<void>();
  final sockets = <Socket>[];
  final subscriptions = <StreamSubscription<dynamic>>[];
  final bytes = <int>[];
  final clock = Stopwatch()..start();
  int? helloUs;
  int? disconnectUs;
  SilentPeer._(this.listener) {
    subscriptions.add(
      listener.listen((socket) {
        sockets.add(socket);
        if (!connected.isCompleted) connected.complete();
        unawaited(socket.done.then<void>((_) {}, onError: (Object _) {}));
        subscriptions.add(
          socket.listen(
            (data) {
              bytes.addAll(data);
              if (bytes.length >= 9 &&
                  bytes[0] == 22 &&
                  bytes[1] == 3 &&
                  bytes[5] == 1) {
                final recordLength = bytes[3] * 256 + bytes[4];
                if (bytes.length >= recordLength + 5 && !hello.isCompleted) {
                  helloUs = clock.elapsedMicroseconds;
                  hello.complete();
                }
              }
            },
            onDone: _gone,
            onError: (Object _) => _gone(),
          ),
        );
      }),
    );
  }
  void _gone() {
    if (!disconnected.isCompleted) {
      disconnectUs = clock.elapsedMicroseconds;
      disconnected.complete();
    }
  }

  static Future<SilentPeer> start() async =>
      SilentPeer._(await ServerSocket.bind(InternetAddress.loopbackIPv4, 0));
  Uri get url => Uri.parse('https://127.0.0.1:${listener.port}');
  Future<void> close() async {
    for (final socket in sockets) {
      socket.destroy();
    }
    await listener.close();
    for (final subscription in subscriptions) {
      await subscription.cancel();
    }
  }
}

class ObservedAttempt {
  bool settled = false;
  Object? failure;
  late final Future<void> done;
  ObservedAttempt(ReceiptApiService service) {
    done = service
        .parseReceipt('synthetic')
        .then<void>(
          (_) {
            settled = true;
          },
          onError: (Object error) {
            failure = error;
            settled = true;
          },
        );
  }
}

ReceiptApiService makeService(
  Uri url,
  http.Client Function() client, {
  Duration timeout = const Duration(seconds: 5),
}) => ReceiptApiService.forTesting(
  baseUrl: url,
  createClient: client,
  timeout: timeout,
  prepareImage:
      (_) async => http.MultipartFile.fromString(
        'image',
        'synthetic',
        filename: 'receipt.jpg',
      ),
);

SecurityContext trustFixture() =>
    SecurityContext(withTrustedRoots: false)
      ..setTrustedCertificates(fixture.root);

class TlsPeer {
  final HttpServer server;
  final requests = <String>[];
  final bodies = <String>[];
  final contentTypes = <String>[];
  final failures = <Object>[];
  final tasks = <Future<void>>[];
  late final StreamSubscription<HttpRequest> accept;
  TlsPeer._(this.server, List<int> statuses) {
    accept = server.listen(
      (request) {
        tasks.add(
          () async {
            requests.add('${request.method} ${request.uri.path}');
            contentTypes.add(request.headers.contentType.toString());
            bodies.add(
              utf8.decode(
                await request.fold<List<int>>(<int>[], (a, b) => a..addAll(b)),
              ),
            );
            final status =
                statuses[(requests.length - 1).clamp(0, statuses.length - 1)];
            request.response.statusCode = status;
            if ([302, 303, 307].contains(status)) {
              request.response.headers.set('location', '/forbidden');
            }
            request.response.headers.contentType = ContentType.json;
            request.response.write('{"items":[]}');
            await request.response.close();
          }().catchError((Object error) {
            failures.add(error);
          }),
        );
      },
      onError: (Object error) {
        failures.add(error);
      },
    );
  }
  static Future<TlsPeer> start({List<int> statuses = const [200]}) async {
    final context =
        SecurityContext()
          ..useCertificateChain(fixture.cert)
          ..usePrivateKey(fixture.key);
    return TlsPeer._(
      await HttpServer.bindSecure(InternetAddress.loopbackIPv4, 0, context),
      statuses,
    );
  }

  Uri url({String host = 'localhost'}) =>
      Uri.parse('https://$host:${server.port}');
  Future<void> close() async {
    await server.close(force: true);
    await accept.cancel();
    await Future.wait(tasks);
  }
}

void main() {
  setUpAll(() async {
    fixture = await ReceiptTlsFixture.create();
  });
  tearDownAll(() => fixture.close());
  for (final action in ['deadline', 'cancel', 'dispose']) {
    test(
      'TLS actual ClientHello $action settles, disconnects and joins',
      () async {
        final peer = await SilentPeer.start();
        final client = ReceiptIoClient();
        final service = makeService(
          peer.url,
          () => client,
          timeout:
              action == 'deadline'
                  ? const Duration(milliseconds: 350)
                  : const Duration(seconds: 5),
        );
        final attempt = ObservedAttempt(service);
        try {
          await peer.hello.future.timeout(budget);
          expect(attempt.settled, isFalse);
          expect(peer.disconnected.isCompleted, isFalse);
          if (action == 'cancel') service.cancel();
          if (action == 'dispose') service.dispose();
          var ended = true;
          try {
            await attempt.done.timeout(const Duration(milliseconds: 850));
          } on TimeoutException {
            ended = false;
          }
          var gone = true;
          try {
            await peer.disconnected.future.timeout(
              const Duration(milliseconds: 300),
            );
          } on TimeoutException {
            gone = false;
          }
          debugPrintSynchronously(
            jsonEncode({
              'proof': action,
              'clientHello': true,
              'clientHelloBytes': peer.bytes.length,
              'attemptSettled': attempt.settled,
              'peerDisconnected': gone,
              'helloUs': peer.helloUs,
              'disconnectUs': peer.disconnectUs,
              'fixtureCleanupStarted': false,
            }),
          );
          expect(
            ended,
            isTrue,
            reason: 'TLS handshake must not outlive the owned attempt',
          );
          expect(
            gone,
            isTrue,
            reason: 'actual TLS peer must disconnect before fixture cleanup',
          );
          expect(attempt.failure, isA<ReceiptParseException>());
          expect(
            (attempt.failure as ReceiptParseException).isCancelled,
            action != 'deadline',
          );
          await client.finish().timeout(budget);
          expect(peer.sockets.length, 1);
        } finally {
          service.dispose();
          await peer.close();
          await attempt.done.timeout(budget);
          await client.finish().timeout(budget);
        }
      },
    );
  }
  test('TLS teardown is joined even after actual peer disconnection', () async {
    final peer = await SilentPeer.start();
    final entered = Completer<void>(), release = Completer<void>();
    final client = ReceiptIoClient.forTesting(
      afterTeardown: () {
        entered.complete();
        return release.future;
      },
    );
    final service = makeService(peer.url, () => client);
    final attempt = ObservedAttempt(service);
    try {
      await peer.hello.future.timeout(budget);
      service.cancel();
      await peer.disconnected.future.timeout(budget);
      await entered.future.timeout(budget);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(
        attempt.settled,
        isFalse,
        reason: 'native teardown join must hold attempt settlement',
      );
      release.complete();
      await attempt.done.timeout(budget);
      expect(attempt.failure, isA<ReceiptParseException>());
    } finally {
      if (!release.isCompleted) release.complete();
      service.dispose();
      await peer.close();
      await attempt.done.timeout(budget);
      await client.finish().timeout(budget);
    }
  });
  for (final action in ['deadline', 'cancel', 'dispose']) {
    test(
      'setup $action owns late setup completion without opening a peer',
      () async {
        final peer = await SilentPeer.start();
        final entered = Completer<void>(), release = Completer<void>();
        final client = ReceiptIoClient.forTesting(
          beforeConnect: () {
            entered.complete();
            return release.future;
          },
        );
        final service = makeService(
          peer.url,
          () => client,
          timeout:
              action == 'deadline'
                  ? const Duration(milliseconds: 120)
                  : const Duration(seconds: 5),
        );
        final attempt = ObservedAttempt(service);
        try {
          await entered.future.timeout(budget);
          if (action == 'cancel') service.cancel();
          if (action == 'dispose') service.dispose();
          if (action == 'deadline') {
            await Future<void>.delayed(const Duration(milliseconds: 160));
          }
          await Future<void>.delayed(const Duration(milliseconds: 20));
          expect(
            attempt.settled,
            isFalse,
            reason: 'setup future remains owned until it can close',
          );
          release.complete();
          await attempt.done.timeout(budget);
          expect(attempt.failure, isA<ReceiptParseException>());
          expect(peer.sockets, isEmpty);
        } finally {
          if (!release.isCompleted) release.complete();
          service.dispose();
          await peer.close();
          await attempt.done.timeout(budget);
          await client.finish().timeout(budget);
        }
      },
    );
  }
  for (final mode in ['trusted', 'bad-ca', 'bad-hostname']) {
    test('TLS $mode preserves validation and receipt upload', () async {
      final peer = await TlsPeer.start();
      final client = ObservedTransport(
        ReceiptIoClient.forTesting(
          context: mode == 'bad-ca' ? null : trustFixture(),
        ),
      );
      final service = makeService(
        peer.url(host: mode == 'bad-hostname' ? '127.0.0.1' : 'localhost'),
        () => client,
      );
      try {
        if (mode == 'trusted') {
          expect((await service.parseReceipt('synthetic')).items, isEmpty);
          expect(peer.requests, ['POST /api/receipts/parse']);
          expect(
            peer.bodies.single,
            contains('name="image"; filename="receipt.jpg"'),
          );
          expect(peer.bodies.single, contains('synthetic'));
          expect(
            peer.contentTypes.single,
            startsWith('multipart/form-data; boundary='),
          );
          expect(peer.failures, isEmpty);
        } else {
          await expectLater(
            service.parseReceipt('synthetic'),
            throwsA(isA<ReceiptParseException>()),
          );
          expect(
            peer.requests,
            isEmpty,
            reason: 'untrusted TLS must not transmit a POST',
          );
          expect(client.transportError, isA<HandshakeException>());
          expect(
            client.transportError.toString(),
            contains('CERTIFICATE_VERIFY_FAILED'),
          );
        }
        await client.finish().timeout(budget);
      } finally {
        service.dispose();
        await peer.close();
        await client.finish().timeout(budget);
      }
    });
  }
  for (final action in ['deadline', 'cancel', 'dispose']) {
    test(
      'actual TCP setup $action disconnects before TLS and joins late handoff',
      () async {
        final peer = await SilentPeer.start();
        final entered = Completer<void>(), release = Completer<void>();
        final client = ReceiptIoClient.forTesting(
          afterTcpConnect: () {
            entered.complete();
            return release.future;
          },
        );
        final service = makeService(
          peer.url,
          () => client,
          timeout:
              action == 'deadline'
                  ? const Duration(milliseconds: 120)
                  : const Duration(seconds: 5),
        );
        final attempt = ObservedAttempt(service);
        try {
          await entered.future.timeout(budget);
          await peer.connected.future.timeout(budget);
          if (action == 'cancel') service.cancel();
          if (action == 'dispose') service.dispose();
          await peer.disconnected.future.timeout(budget);
          expect(peer.bytes, isEmpty);
          expect(attempt.settled, isFalse);
          release.complete();
          await attempt.done.timeout(budget);
          expect(attempt.failure, isA<ReceiptParseException>());
          expect(peer.sockets.length, 1);
        } finally {
          if (!release.isCompleted) release.complete();
          service.dispose();
          await peer.close();
          await attempt.done.timeout(budget);
          await client.finish().timeout(budget);
        }
      },
    );
  }
  for (final code in [302, 303, 307]) {
    test('TLS $code is one POST with no redirect', () async {
      final peer = await TlsPeer.start(statuses: [code]);
      final service = makeService(
        peer.url(),
        () => ReceiptIoClient.forTesting(context: trustFixture()),
      );
      try {
        await expectLater(
          service.parseReceipt('synthetic'),
          throwsA(isA<ReceiptParseException>()),
        );
        expect(peer.requests, ['POST /api/receipts/parse']);
      } finally {
        service.dispose();
        await peer.close();
      }
    });
  }
  for (final action in ['deadline', 'cancel', 'dispose']) {
    test(
      'stalled TLS $action preserves deliberate retry wire ownership',
      () async {
        final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
        final serverContext =
            SecurityContext()
              ..useCertificateChain(fixture.cert)
              ..usePrivateKey(fixture.key);
        final hello = Completer<void>(), gone = Completer<void>();
        final sockets = <Socket>[],
            tasks = <Future<void>>[],
            subscriptions = <StreamSubscription<dynamic>>[];
        final requests = <String>[];
        final failures = <Object>[];
        var connections = 0;
        final accept = server.listen((socket) {
          sockets.add(socket);
          connections++;
          unawaited(socket.done.then<void>((_) {}, onError: (Object _) {}));
          if (connections == 1) {
            final bytes = <int>[];
            subscriptions.add(
              socket.listen(
                (data) {
                  bytes.addAll(data);
                  if (bytes.length >= 9 &&
                      bytes[0] == 22 &&
                      bytes[5] == 1 &&
                      bytes.length >= 5 + bytes[3] * 256 + bytes[4] &&
                      !hello.isCompleted) {
                    hello.complete();
                  }
                },
                onDone: () {
                  if (!gone.isCompleted) gone.complete();
                },
                onError: (Object _) {
                  if (!gone.isCompleted) gone.complete();
                },
              ),
            );
          } else {
            tasks.add(
              () async {
                final secure = await SecureSocket.secureServer(
                  socket,
                  serverContext,
                );
                sockets.add(secure);
                unawaited(
                  secure.done.then<void>((_) {}, onError: (Object _) {}),
                );
                final ended = Completer<void>();
                final bytes = <int>[];
                var replied = false;
                subscriptions.add(
                  secure.listen(
                    (data) {
                      bytes.addAll(data);
                      final text = latin1.decode(bytes);
                      final end = text.indexOf('\r\n\r\n');
                      if (replied || end < 0) return;
                      final match = RegExp(
                        r'content-length: (\d+)',
                        caseSensitive: false,
                      ).firstMatch(text);
                      if (match == null ||
                          bytes.length < end + 4 + int.parse(match.group(1)!)) {
                        return;
                      }
                      replied = true;
                      requests.add(text.split('\r\n').first);
                      secure.write(
                        'HTTP/1.1 200 OK\r\nContent-Length: 12\r\nConnection: close\r\n\r\n{"items":[]}',
                      );
                      unawaited(
                        secure.flush().then<void>(
                          (_) async {
                            await secure.close();
                          },
                          onError: (Object error) {
                            failures.add(error);
                          },
                        ),
                      );
                    },
                    onDone: () {
                      if (!ended.isCompleted) ended.complete();
                    },
                    onError: (Object error) {
                      failures.add(error);
                      if (!ended.isCompleted) ended.complete();
                    },
                  ),
                );
                await ended.future;
              }().catchError((Object error) {
                failures.add(error);
              }),
            );
          }
        });
        final clients = <ReceiptIoClient>[];
        final service = makeService(
          Uri.parse('https://localhost:${server.port}'),
          () {
            final client = ReceiptIoClient.forTesting(context: trustFixture());
            clients.add(client);
            return client;
          },
          timeout:
              action == 'deadline'
                  ? const Duration(milliseconds: 350)
                  : const Duration(seconds: 5),
        );
        final attempt = ObservedAttempt(service);
        try {
          await hello.future.timeout(budget);
          if (action == 'cancel') service.cancel();
          if (action == 'dispose') service.dispose();
          await attempt.done.timeout(budget);
          await gone.future.timeout(budget);
          expect(attempt.failure, isA<ReceiptParseException>());
          expect(requests, isEmpty);
          expect(connections, 1);
          if (action == 'dispose') {
            await expectLater(
              service.parseReceipt('synthetic'),
              throwsA(
                isA<ReceiptParseException>().having(
                  (e) => e.isCancelled,
                  'disposed',
                  true,
                ),
              ),
            );
            expect(connections, 1);
          } else {
            expect((await service.parseReceipt('synthetic')).items, isEmpty);
            expect(requests, ['POST /api/receipts/parse HTTP/1.1']);
            expect(connections, 2);
          }
          for (final client in clients) {
            await client.finish().timeout(budget);
          }
          expect(failures, isEmpty);
        } finally {
          service.dispose();
          for (final client in clients) {
            await client.finish().timeout(budget);
          }
          for (final socket in sockets) {
            socket.destroy();
          }
          await attempt.done.timeout(budget);
          await server.close();
          await accept.cancel();
          for (final sub in subscriptions) {
            await sub.cancel();
          }
          await Future.wait(tasks).timeout(budget);
        }
      },
    );
  }
  test(
    'TLS manual retry is exactly one new POST per explicit attempt',
    () async {
      final peer = await TlsPeer.start(statuses: [503, 200]);
      final clients = <ReceiptIoClient>[];
      final service = makeService(peer.url(), () {
        final c = ReceiptIoClient.forTesting(context: trustFixture());
        clients.add(c);
        return c;
      });
      try {
        await expectLater(
          service.parseReceipt('synthetic'),
          throwsA(isA<ReceiptParseException>()),
        );
        expect(peer.requests, ['POST /api/receipts/parse']);
        expect((await service.parseReceipt('synthetic')).items, isEmpty);
        expect(peer.requests, [
          'POST /api/receipts/parse',
          'POST /api/receipts/parse',
        ]);
        expect(clients.length, 2);
        for (final client in clients) {
          await client.finish().timeout(budget);
        }
      } finally {
        service.dispose();
        await peer.close();
        for (final c in clients) {
          await c.finish().timeout(budget);
        }
      }
    },
  );
  test(
    'debug HTTP control uploads through the same constructor seam',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final tasks = <Future<void>>[];
      var posts = 0;
      final accept = server.listen((request) {
        tasks.add(() async {
          posts++;
          await request.drain<void>();
          request.response.write('{"items":[]}');
          await request.response.close();
        }());
      });
      final client = ReceiptIoClient();
      final service = makeService(
        Uri.parse('http://127.0.0.1:${server.port}'),
        () => client,
      );
      try {
        expect((await service.parseReceipt('synthetic')).items, isEmpty);
        expect(posts, 1);
        await client.finish().timeout(budget);
      } finally {
        service.dispose();
        await server.close(force: true);
        await accept.cancel();
        await Future.wait(tasks);
        await client.finish().timeout(budget);
      }
    },
  );
}
