import 'dart:async';
import 'dart:convert';
import 'package:checks_frontend/services/receipt_api_service.dart';
import 'package:checks_frontend/services/receipt_parser.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

class ScriptClient extends http.BaseClient {
  final FutureOr<http.StreamedResponse> Function(http.BaseRequest) reply;
  int closes = 0;
  int sends = 0;
  http.BaseRequest? request;
  ScriptClient(this.reply);
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    sends++;
    this.request = request;
    return reply(request);
  }

  @override
  void close() {
    closes++;
  }
}

ReceiptApiService serviceFor(
  ScriptClient client, {
  Duration timeout = const Duration(seconds: 45),
  Duration Function()? elapsed,
  DateTime Function()? now,
  Future<http.MultipartFile> Function(String)? prepareImage,
}) => ReceiptApiService.forTesting(
  baseUrl: Uri.parse('http://127.0.0.1:1'),
  createClient: () => client,
  timeout: timeout,
  elapsed: elapsed,
  now: now,
  prepareImage:
      prepareImage ?? (_) async => http.MultipartFile.fromBytes('image', [1]),
);
http.StreamedResponse response(
  String body, {
  int status = 200,
  Map<String, String> headers = const {},
}) => http.StreamedResponse(
  Stream.value(utf8.encode(body)),
  status,
  headers: headers,
);
final parseFailure = isA<ReceiptParseException>();

void main() {
  test(
    'success closes owned client and completes abort listeners without later timeout',
    () async {
      final client = ScriptClient((_) => response('{"items":[]}'));
      // Hold logical elapsed time steady for this successful scripted response.
      // Deadline behavior has separate stalled/late-response cases below.
      final service = serviceFor(client, elapsed: () => Duration.zero);
      final timers = <Timer>[];
      final durations = <Duration>[];
      try {
        await runZoned(
          () async {
            await service.parseReceipt('x');
            expect(client.closes, 1);
            expect(client.request, isA<http.AbortableMultipartRequest>());
            expect(client.request!.followRedirects, isFalse);
            var released = false;
            await (client.request as http.Abortable).abortTrigger!.then(
              (_) => released = true,
            );
            expect(released, isTrue);
            expect(durations, [const Duration(seconds: 45)]);
            expect(timers, hasLength(1));
            expect(timers.single.isActive, isFalse);
            expect(client.closes, 1);
            service.dispose();
            expect(client.closes, 1);
          },
          zoneSpecification: ZoneSpecification(
            createTimer: (self, parent, zone, duration, callback) {
              durations.add(duration);
              final timer = parent.createTimer(zone, duration, callback);
              timers.add(timer);
              return timer;
            },
          ),
        );
      } finally {
        service.dispose();
        // Independent test cleanup also runs when a cancellation guard is removed.
        for (final timer in timers) {
          timer.cancel();
        }
      }
    },
  );
  test(
    'setup is within deadline and late file completion never sends',
    () async {
      final file = Completer<http.MultipartFile>();
      final client = ScriptClient((_) => response('{"items":[]}'));
      final service = serviceFor(
        client,
        timeout: const Duration(milliseconds: 20),
        prepareImage: (_) => file.future,
      );
      await expectLater(
        service.parseReceipt('x'),
        throwsA(
          parseFailure.having(
            (e) => e.message,
            'timeout',
            contains('timed out'),
          ),
        ),
      );
      expect(client.sends, 0);
      expect(client.closes, 1);
      file.complete(http.MultipartFile.fromBytes('image', [1]));
      await Future<void>.delayed(Duration.zero);
      expect(client.sends, 0);
    },
  );
  test(
    'one monotonic deadline covers setup send and full body rather than resetting',
    () async {
      var elapsed = Duration.zero;
      final body = StreamController<List<int>>();
      final client = ScriptClient((_) {
        elapsed = const Duration(seconds: 44);
        return http.StreamedResponse(body.stream, 200);
      });
      final service = serviceFor(
        client,
        elapsed: () => elapsed,
        prepareImage: (_) async {
          elapsed = const Duration(seconds: 40);
          return http.MultipartFile.fromBytes('image', [1]);
        },
      );
      final result = service.parseReceipt('x');
      final check = expectLater(
        result,
        throwsA(
          parseFailure.having(
            (e) => e.message,
            'timeout',
            contains('timed out'),
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      elapsed = const Duration(seconds: 46);
      body.add(utf8.encode('{"items":[]}'));
      await check;
      await body.close();
      expect(client.closes, 1);
    },
  );
  test(
    'synchronous typed parse elapsed beyond deadline cannot return success',
    () async {
      var checks = 0;
      final client = ScriptClient((_) => response('{"items":[]}'));
      // The final checks run after UTF-8 and typed parsing. No timer preemption claim.
      final service = serviceFor(
        client,
        elapsed:
            () => ++checks >= 9 ? const Duration(seconds: 46) : Duration.zero,
      );
      await expectLater(
        service.parseReceipt('x'),
        throwsA(
          parseFailure.having(
            (e) => e.message,
            'timeout',
            contains('timed out'),
          ),
        ),
      );
      expect(client.closes, 1);
    },
  );
  test(
    'body stalls are cancelled and subscription cleanup is awaited',
    () async {
      var cancelled = false;
      final body = StreamController<List<int>>(
        onCancel: () async {
          await Future<void>.delayed(Duration.zero);
          cancelled = true;
        },
      );
      final client = ScriptClient(
        (_) => http.StreamedResponse(body.stream, 200),
      );
      final service = serviceFor(
        client,
        timeout: const Duration(milliseconds: 20),
      );
      await expectLater(service.parseReceipt('x'), throwsA(parseFailure));
      expect(cancelled, isTrue);
      expect(client.closes, 1);
      await body.close();
    },
  );
  test(
    'late send completion after explicit cancellation is discarded and body cancelled',
    () async {
      final headers = Completer<http.StreamedResponse>();
      var cancelled = false;
      final body = StreamController<List<int>>(
        onCancel: () => cancelled = true,
      );
      final client = ScriptClient((_) => headers.future);
      final service = serviceFor(client);
      final pending = service.parseReceipt('x');
      final check = expectLater(
        pending,
        throwsA(parseFailure.having((e) => e.isCancelled, 'cancelled', isTrue)),
      );
      await Future<void>.delayed(Duration.zero);
      service.cancel();
      headers.complete(http.StreamedResponse(body.stream, 200));
      await check;
      expect(cancelled, isTrue);
      expect(client.closes, 1);
      await body.close();
    },
  );
  for (final status in [200, 503]) {
    for (final length in <int?>[null, 1, 2 * 1024 * 1024]) {
      test(
        'cap+1 response aborts promptly status=$status declared=$length',
        () async {
          var tailRead = false;
          var cancelled = false;
          Stream<List<int>> body() async* {
            try {
              yield List.filled(1024 * 1024, 32);
              yield [32];
              tailRead = true;
              yield utf8.encode('PRIVATE_SERVER_TAINT');
            } finally {
              cancelled = true;
            }
          }

          final client = ScriptClient(
            (_) => http.StreamedResponse(body(), status, contentLength: length),
          );
          await expectLater(
            serviceFor(client).parseReceipt('x'),
            throwsA(
              parseFailure.having(
                (e) => e.message,
                'finite size error',
                ReceiptValidationException.message,
              ),
            ),
          );
          expect(tailRead, isFalse);
          expect(cancelled, isTrue);
          expect(client.closes, 1);
        },
      );
    }
  }
  test(
    'exactly 1MiB decoded UTF-8 body is accepted without a Content-Length',
    () async {
      const prefix = '{"items":[],"vendor":"🧾"}';
      final body = prefix + ' ' * (1024 * 1024 - utf8.encode(prefix).length);
      final client = ScriptClient((_) => response(body));
      expect((await serviceFor(client).parseReceipt('x')).vendor, '🧾');
      expect(client.closes, 1);
    },
  );
  for (final body in [
    '{"items":"bad"}',
    '{"tax":"bad"}',
    '{"items":[{"quantity":501}]}',
    '{"tax":1e999}',
    '{"x":${'[' * 17}0${']' * 17}}',
    '{"vendor":"${'🧾' * 256}"}',
    '\uFFFD',
  ]) {
    test(
      'network invalid shape returns useful finite validation (${body.length})',
      () async {
        final client = ScriptClient((_) => response(body));
        await expectLater(
          serviceFor(client).parseReceipt('x'),
          throwsA(
            parseFailure.having(
              (e) => e.message,
              'message',
              ReceiptValidationException.message,
            ),
          ),
        );
        expect(client.closes, 1);
      },
    );
  }
  for (final pair in [
    (429, 'rate_limited'),
    (413, 'image_too_large'),
    (503, 'auth_failed'),
    (503, 'overloaded'),
    (503, 'provider_down'),
    (422, 'invalid_request'),
    (422, 'bad_response'),
    (400, 'invalid_peer'),
    (599, 'unknown'),
    (307, 'unknown'),
  ]) {
    test(
      'finite error status ${pair.$1} code ${pair.$2} never exposes server text',
      () async {
        final client = ScriptClient(
          (_) => response(
            jsonEncode({
              'error': 'PRIVATE https://sensitive.invalid/image',
              'code': pair.$2,
            }),
            status: pair.$1,
          ),
        );
        await expectLater(
          serviceFor(client).parseReceipt('x'),
          throwsA(
            parseFailure
                .having((e) => e.toString(), 'safe', isNot(contains('PRIVATE')))
                .having(
                  (e) => e.toString(),
                  'safe URL',
                  isNot(contains('https:')),
                )
                .having((e) => e.isRateLimit, 'rate', pair.$1 == 429),
          ),
        );
        expect(client.sends, 1);
        expect(client.closes, 1);
      },
    );
  }
  for (final pair in <(String?, int?)>[
    (null, null),
    ('1', 1),
    ('0', 1),
    ('86400', 86400),
    ('86401', null),
    ('9' * 128, null),
    ('9' * 129, null),
    ('junk', null),
    ('Tue, 01 Jan 2030 00:00:10 GMT', 10),
    ('Wed, 02 Jan 2030 00:00:00 GMT', 86400),
    ('Wed, 02 Jan 2030 00:00:01 GMT', null),
    ('Mon, 31 Dec 2029 23:59:59 GMT', 1),
  ]) {
    test(
      'bounded Retry-After ${pair.$1?.length}/${pair.$2} never shortens longer valid wait',
      () async {
        final client = ScriptClient(
          (_) => response(
            '{}',
            status: 429,
            headers: {if (pair.$1 != null) 'retry-after': pair.$1!},
          ),
        );
        await expectLater(
          serviceFor(client, now: () => DateTime.utc(2030)).parseReceipt('x'),
          throwsA(
            parseFailure.having((e) => e.retryAfterSeconds, 'retry', pair.$2),
          ),
        );
      },
    );
  }
  test(
    'failed attempt permits deliberate manual retry using a new owned client',
    () async {
      final clients = [
        ScriptClient((_) => response('{}', status: 503)),
        ScriptClient((_) => response('{"items":[]}')),
      ];
      var index = 0;
      final service = ReceiptApiService.forTesting(
        baseUrl: Uri.parse('http://127.0.0.1:1'),
        createClient: () => clients[index++],
        prepareImage: (_) async => http.MultipartFile.fromBytes('image', [1]),
      );
      await expectLater(service.parseReceipt('x'), throwsA(parseFailure));
      expect((await service.parseReceipt('x')).items, isEmpty);
      expect(clients.map((c) => c.sends), [1, 1]);
      expect(clients.map((c) => c.closes), [1, 1]);
      service.dispose();
      await expectLater(
        service.parseReceipt('x'),
        throwsA(parseFailure.having((e) => e.isCancelled, 'cancel', isTrue)),
      );
      expect(index, 2);
    },
  );
  test('deadline is rechecked after owned client cleanup', () async {
    var elapsed = Duration.zero;
    final client = CleanupClient(() => elapsed = const Duration(seconds: 46));
    await expectLater(
      serviceFor(client, elapsed: () => elapsed).parseReceipt('x'),
      throwsA(
        parseFailure.having((e) => e.message, 'timeout', contains('timed out')),
      ),
    );
    expect(client.closes, 1);
  });
  for (final failure in [false, true]) {
    test(
      'owned deadline timer is cancelled on ${failure ? 'failure' : 'success'} and abort listeners settle',
      () async {
        final timers = <Timer>[];
        final client = ScriptClient(
          (_) => response(failure ? '{"items":"bad"}' : '{"items":[]}'),
        );
        await runZoned(
          () async {
            final service = serviceFor(client);
            if (failure) {
              await expectLater(
                service.parseReceipt('x'),
                throwsA(parseFailure),
              );
            } else {
              await service.parseReceipt('x');
            }
            await (client.request as http.Abortable).abortTrigger;
          },
          zoneSpecification: ZoneSpecification(
            createTimer: (self, parent, zone, duration, callback) {
              final timer = parent.createTimer(zone, duration, callback);
              timers.add(timer);
              return timer;
            },
          ),
        );
        expect(timers, hasLength(1));
        expect(timers.single.isActive, isFalse);
        expect(client.closes, 1);
      },
    );
  }
  test(
    'simultaneous operations own distinct clients; explicit cancel closes each once',
    () async {
      final bodies = List.generate(2, (_) => StreamController<List<int>>());
      final clients = List.generate(
        2,
        (i) =>
            ScriptClient((_) => http.StreamedResponse(bodies[i].stream, 200)),
      );
      var index = 0;
      final service = ReceiptApiService.forTesting(
        baseUrl: Uri.parse('http://127.0.0.1:1'),
        createClient: () => clients[index++],
        prepareImage: (_) async => http.MultipartFile.fromBytes('image', [1]),
      );
      final assertions = [
        for (var i = 0; i < 2; i++)
          expectLater(
            service.parseReceipt('x'),
            throwsA(
              parseFailure.having((e) => e.isCancelled, 'cancel', isTrue),
            ),
          ),
      ];
      await Future<void>.delayed(Duration.zero);
      service.cancel();
      service.cancel();
      await Future.wait(assertions);
      expect(clients.map((c) => c.closes), [1, 1]);
      for (final body in bodies) {
        await body.close();
      }
    },
  );
  test('invalid UTF-8 is a finite validation error', () async {
    final client = ScriptClient(
      (_) => http.StreamedResponse(Stream.value([0xff]), 200),
    );
    await expectLater(
      serviceFor(client).parseReceipt('x'),
      throwsA(
        parseFailure.having(
          (e) => e.message,
          'validation',
          ReceiptValidationException.message,
        ),
      ),
    );
  });
  test(
    'late setup failure after cancellation cannot become an unhandled upload',
    () async {
      final file = Completer<http.MultipartFile>();
      final client = ScriptClient((_) => response('{"items":[]}'));
      final service = serviceFor(client, prepareImage: (_) => file.future);
      final check = expectLater(
        service.parseReceipt('x'),
        throwsA(parseFailure.having((e) => e.isCancelled, 'cancel', isTrue)),
      );
      service.dispose();
      await check;
      file.completeError(StateError('PRIVATE_FILE_PATH'));
      await Future<void>.delayed(Duration.zero);
      expect(client.sends, 0);
      expect(client.closes, 1);
    },
  );
}

class CleanupClient extends ScriptClient {
  final void Function() cleanup;
  CleanupClient(this.cleanup) : super((_) => response('{"items":[]}'));
  @override
  void close() {
    super.close();
    cleanup();
  }
}
