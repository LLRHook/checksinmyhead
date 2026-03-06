import 'package:flutter_test/flutter_test.dart';

// Pure logic extracted from GroupManager for testing
List<List<String>> generateSubsets(List<String> sorted, int minSize, int maxSize) {
  final results = <List<String>>[];
  final n = sorted.length;
  final cappedMax = maxSize < n ? maxSize : n;
  for (int size = minSize; size <= cappedMax; size++) {
    _combine(sorted, size, 0, <String>[], results);
  }
  return results;
}

void _combine(List<String> list, int size, int start,
    List<String> current, List<List<String>> results) {
  if (current.length == size) {
    results.add(List<String>.from(current));
    return;
  }
  for (int i = start; i < list.length; i++) {
    current.add(list[i]);
    _combine(list, size, i + 1, current, results);
    current.removeLast();
  }
}

void main() {
  group('Co-occurrence subset generation', () {
    test('generates pairs from 3 people', () {
      final subsets = generateSubsets(['alice', 'bob', 'charlie'], 2, 5);
      expect(subsets, containsAll([
        ['alice', 'bob'],
        ['alice', 'charlie'],
        ['bob', 'charlie'],
        ['alice', 'bob', 'charlie'],
      ]));
      expect(subsets.length, equals(4));
    });

    test('generates only pairs from 2 people', () {
      final subsets = generateSubsets(['alice', 'bob'], 2, 5);
      expect(subsets.length, equals(1));
      expect(subsets.first, equals(['alice', 'bob']));
    });

    test('caps at maxSize', () {
      final subsets = generateSubsets(['a', 'b', 'c', 'd'], 2, 2);
      expect(subsets.every((s) => s.length == 2), isTrue);
      expect(subsets.length, equals(6)); // C(4,2) = 6
    });

    test('handles single person (no subsets)', () {
      final subsets = generateSubsets(['alice'], 2, 5);
      expect(subsets, isEmpty);
    });

    test('handles 5 people without explosion', () {
      final subsets = generateSubsets(['a', 'b', 'c', 'd', 'e'], 2, 5);
      // C(5,2) + C(5,3) + C(5,4) + C(5,5) = 10 + 10 + 5 + 1 = 26
      expect(subsets.length, equals(26));
    });
  });
}
