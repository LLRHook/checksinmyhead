import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Smart people scoring', () {
    double score(int useCount, int daysSinceLastUse) {
      final recencyFactor = 1.0 / (1.0 + daysSinceLastUse * 0.1);
      return useCount * recencyFactor;
    }

    test('frequent recent user scores higher than infrequent recent', () {
      final frequent = score(10, 0);
      final infrequent = score(1, 0);
      expect(frequent, greaterThan(infrequent));
    });

    test('recent user scores higher than stale user with same frequency', () {
      final recent = score(5, 0);
      final stale = score(5, 30);
      expect(recent, greaterThan(stale));
    });

    test('very frequent stale user can still beat infrequent recent user', () {
      final frequentStale = score(20, 14);
      final infrequentRecent = score(2, 0);
      expect(frequentStale, greaterThan(infrequentRecent));
    });

    test('recency factor decays correctly', () {
      final today = score(1, 0);
      final tenDays = score(1, 10);
      final thirtyDays = score(1, 30);
      expect(today, greaterThan(tenDays));
      expect(tenDays, greaterThan(thirtyDays));
    });

    test('zero days since use gives recency factor of 1.0', () {
      expect(score(5, 0), equals(5.0));
    });
  });
}
