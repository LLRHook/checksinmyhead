import 'dart:async';
import 'dart:io';
import 'package:checks_frontend/services/receipt_api_service.dart';
import 'package:checks_frontend/services/receipt_io_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'fixtures/receipt_tls_fixture.dart';
import 'tls_ownership_test.dart' as tls;

const _budget = Duration(seconds: 3);

// Real local competitors, separately owned from the implementation's endpoints.
class _Competitors {
  final sockets = <Socket>[];
  final subscriptions = <StreamSubscription<List<int>>>[];
  Future<void> connect(int port) async {
    final socket = await Socket.connect(InternetAddress.loopbackIPv4, port);
    sockets.add(socket);
    unawaited(socket.done.then<void>((_) {}, onError: (Object _) {}));
    subscriptions.add(socket.listen((_) {}, onError: (Object _) {}));
    // If incorrectly paired, these bytes would corrupt the upstream protocol.
    socket.write('WRONG LOCAL ENDPOINT\r\n');
  }

  Future<void> close() async {
    for (final socket in sockets) {
      socket.destroy();
    }
    for (final subscription in subscriptions) {
      await subscription.cancel();
    }
    for (final socket in sockets) {
      await socket.close().then<void>((_) {}, onError: (Object _) {});
    }
  }
}

void _released(ReceiptIoClient client) {
  for (final key in [
    'sockets',
    'pendingAccepts',
    'tasks',
    'pumps',
    'listeners',
  ]) {
    expect(client.resourceCounts[key], 0, reason: 'joined owner releases $key');
  }
}

void main() {
  setUpAll(() async {
    tls.fixture = await ReceiptTlsFixture.create();
  });
  tearDownAll(() => tls.fixture.close());

  for (final early in [false, true]) {
    test(
      'relay pairs actual endpoint with competing first peer; early accept=$early',
      () async {
        final peer = await tls.TlsPeer.start();
        final competitors = _Competitors();
        final first = Completer<void>(), second = Completer<void>();
        var accepts = 0;
        final client = ReceiptIoClient.forTesting(
          context: tls.trustFixture(),
          afterRelayListen: (port) async {
            await competitors.connect(port);
            await first.future.timeout(_budget);
          },
          beforeLocalRegistration:
              early ? () => second.future.timeout(_budget) : null,
          onAccept: (_) {
            accepts++;
            if (accepts == 1) first.complete();
            if (accepts == 2) second.complete();
          },
        );
        final service = tls.makeService(peer.url(), () => client);
        try {
          Object? failure;
          await service
              .parseReceipt('synthetic')
              .then<void>(
                (receipt) => expect(receipt.items, isEmpty),
                onError: (Object error) {
                  failure = error;
                },
              );
          expect(
            failure,
            isNull,
            reason: 'the actual initiated endpoint must win pairing',
          );
          expect(peer.requests, ['POST /api/receipts/parse']);
          expect(
            peer.failures,
            isEmpty,
            reason: 'competitor never reaches TLS upstream',
          );
          expect(client.resourceCounts['acceptedEndpoints'], 2);
          await client.finish().timeout(_budget);
          _released(client);
        } finally {
          service.dispose();
          await competitors.close();
          await peer.close();
          await client.finish().timeout(_budget);
        }
      },
    );
  }
  test('relay accepts honest peer before local future registration', () async {
    final peer = await tls.TlsPeer.start();
    final accepted = Completer<void>();
    final client = ReceiptIoClient.forTesting(
      context: tls.trustFixture(),
      beforeLocalRegistration: () => accepted.future.timeout(_budget),
      onAccept: (_) {
        if (!accepted.isCompleted) accepted.complete();
      },
    );
    final service = tls.makeService(peer.url(), () => client);
    try {
      expect((await service.parseReceipt('synthetic')).items, isEmpty);
      expect(peer.requests.length, 1);
      expect(client.resourceCounts['acceptedEndpoints'], 1);
      _released(client);
    } finally {
      service.dispose();
      await peer.close();
      await client.finish().timeout(_budget);
    }
  });
  for (final localStarted in [false, true]) {
    test(
      'relay flood exhausts eight endpoint budget finitely; local started=$localStarted',
      () async {
        final peer = await tls.SilentPeer.start();
        final competitors = _Competitors();
        var port = 0, accepts = 0, peakSockets = 0;
        var event = Completer<void>();
        late ReceiptIoClient client;
        Future<void> flood(int count) async {
          for (var i = 0; i < count; i++) {
            event = Completer<void>();
            await competitors.connect(port);
            await event.future.timeout(_budget);
          }
        }

        client = ReceiptIoClient.forTesting(
          afterRelayListen: (p) async {
            port = p;
            if (!localStarted) await flood(8);
          },
          beforeLocalRegistration:
              localStarted
                  ? () async {
                    if (accepts == 0) await event.future.timeout(_budget);
                    await flood(7);
                  }
                  : null,
          onAccept: (_) {
            accepts++;
            final count = client.resourceCounts['sockets']!;
            if (count > peakSockets) peakSockets = count;
            if (!event.isCompleted) event.complete();
          },
        );
        final service = tls.makeService(peer.url, () => client);
        final attempt = tls.ObservedAttempt(service);
        try {
          await attempt.done.timeout(_budget, onTimeout: () {});
          expect(
            attempt.settled,
            isTrue,
            reason:
                'the endpoint budget must stop setup without another timer or retry',
          );
          await peer.disconnected.future.timeout(_budget);
          expect(attempt.failure, isA<ReceiptParseException>());
          expect(accepts, 8);
          expect(
            peakSockets,
            lessThanOrEqualTo(10),
          ); // upstream + local + budget
          expect(
            peer.bytes,
            isEmpty,
            reason: 'no wrong pairing or wire request',
          );
          expect(
            peer.sockets.length,
            1,
            reason: 'budget failure has no fallback/retry',
          );
          await client.finish().timeout(_budget);
          _released(client);
          await expectLater(
            Socket.connect(InternetAddress.loopbackIPv4, port),
            throwsA(isA<SocketException>()),
          );
        } finally {
          service.dispose();
          await competitors.close();
          await peer.close();
          await attempt.done.timeout(_budget);
          await client.finish().timeout(_budget);
        }
      },
    );
  }
  for (final stage in ['listener', 'unregistered-local']) {
    test(
      'relay cancellation owns late $stage handoff and closes listener',
      () async {
        final peer = await tls.SilentPeer.start();
        final entered = Completer<void>(),
            release = Completer<void>(),
            accepted = Completer<void>();
        var port = 0;
        final client = ReceiptIoClient.forTesting(
          afterRelayListen: (p) async {
            port = p;
            if (stage == 'listener') {
              entered.complete();
              await release.future;
            }
          },
          beforeLocalRegistration:
              stage == 'unregistered-local'
                  ? () async {
                    await accepted.future.timeout(_budget);
                    entered.complete();
                    await release.future;
                  }
                  : null,
          onAccept: (_) {
            if (!accepted.isCompleted) accepted.complete();
          },
        );
        final service = tls.makeService(peer.url, () => client);
        final attempt = tls.ObservedAttempt(service);
        try {
          await entered.future.timeout(_budget);
          service.cancel();
          await peer.disconnected.future.timeout(_budget);
          expect(
            attempt.settled,
            isFalse,
            reason: 'late application setup stays joined',
          );
          release.complete();
          await attempt.done.timeout(_budget);
          expect(
            (attempt.failure as ReceiptParseException).isCancelled,
            isTrue,
          );
          expect(peer.bytes, isEmpty);
          _released(client);
          await expectLater(
            Socket.connect(InternetAddress.loopbackIPv4, port),
            throwsA(isA<SocketException>()),
          );
        } finally {
          if (!release.isCompleted) release.complete();
          service.dispose();
          await peer.close();
          await attempt.done.timeout(_budget);
          await client.finish().timeout(_budget);
        }
      },
    );
  }
  test(
    'relay setup error after listener creation joins every owned endpoint',
    () async {
      final peer = await tls.SilentPeer.start();
      final client = ReceiptIoClient.forTesting(
        afterRelayListen: (_) async {
          throw StateError('synthetic setup error');
        },
      );
      final service = tls.makeService(peer.url, () => client);
      try {
        await expectLater(
          service.parseReceipt('synthetic'),
          throwsA(isA<ReceiptParseException>()),
        );
        await peer.disconnected.future.timeout(_budget);
        expect(peer.bytes, isEmpty);
        _released(client);
      } finally {
        service.dispose();
        await peer.close();
        await client.finish().timeout(_budget);
      }
    },
  );
  test('overlapping TLS attempts retain independent socket owners', () async {
    final a = await tls.SilentPeer.start(), b = await tls.SilentPeer.start();
    final ca = ReceiptIoClient(), cb = ReceiptIoClient();
    final sa = tls.makeService(a.url, () => ca),
        sb = tls.makeService(b.url, () => cb);
    final aa = tls.ObservedAttempt(sa), ab = tls.ObservedAttempt(sb);
    try {
      await Future.wait([a.hello.future, b.hello.future]).timeout(_budget);
      sa.cancel();
      await aa.done.timeout(_budget);
      await a.disconnected.future.timeout(_budget);
      expect(ab.settled, isFalse);
      expect(b.disconnected.isCompleted, isFalse);
      sb.cancel();
      await ab.done.timeout(_budget);
      await b.disconnected.future.timeout(_budget);
      _released(ca);
      _released(cb);
    } finally {
      sa.dispose();
      sb.dispose();
      await a.close();
      await b.close();
      await Future.wait([
        aa.done,
        ab.done,
        ca.finish(),
        cb.finish(),
      ]).timeout(_budget);
    }
  });
}
