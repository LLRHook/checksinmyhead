import 'package:checks_frontend/services/api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  for (final rate in ['2', '1.25', '2e-3']) {
    test(
      'maintained display rate accepts JSON $rate independent ZAR',
      () async {
        final api = ApiService(
          client: MockClient((r) async {
            expect(r.url.queryParameters, {'from': 'USD', 'to': 'ZAR'});
            return http.Response('{"rate":$rate}', 200);
          }),
        );
        expect(await api.getCurrencyRate('USD', 'ZAR'), double.parse(rate));
      },
    );
  }
  for (final body in [
    '{"rate":0}',
    '{"rate":-1}',
    '{"rate":1e999}',
    '{"rate":"1.25"}',
    '{"value":1.25}',
    '{}',
    '[]',
    'null',
    'malformed',
  ]) {
    test(
      'maintained display rate rejects $body without identity fallback',
      () async {
        final api = ApiService(
          client: MockClient((r) async => http.Response(body, 200)),
        );
        await expectLater(
          api.getCurrencyRate('EUR', 'ZAR'),
          throwsA(isA<ApiException>()),
        );
      },
    );
  }
}
