import 'package:checks_frontend/screens/quick_split/participant_selection/models/group_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Co-occurrence subset generation', () {
    test('generates pairs from 3 people', () {
      final subsets = GroupManager.generateSubsets(
        ['alice', 'bob', 'charlie'],
        2,
        5,
      );
      expect(
        subsets,
        containsAll([
          ['alice', 'bob'],
          ['alice', 'charlie'],
          ['bob', 'charlie'],
          ['alice', 'bob', 'charlie'],
        ]),
      );
      expect(subsets.length, equals(4));
    });

    test('generates only pairs from 2 people', () {
      final subsets = GroupManager.generateSubsets(['alice', 'bob'], 2, 5);
      expect(subsets.length, equals(1));
      expect(subsets.first, equals(['alice', 'bob']));
    });

    test('caps at maxSize', () {
      final subsets = GroupManager.generateSubsets(['a', 'b', 'c', 'd'], 2, 2);
      expect(subsets.every((s) => s.length == 2), isTrue);
      expect(subsets.length, equals(6)); // C(4,2) = 6
    });

    test('handles single person (no subsets)', () {
      final subsets = GroupManager.generateSubsets(['alice'], 2, 5);
      expect(subsets, isEmpty);
    });

    test('handles 5 people without explosion', () {
      final subsets = GroupManager.generateSubsets(
        ['a', 'b', 'c', 'd', 'e'],
        2,
        5,
      );
      // C(5,2) + C(5,3) + C(5,4) + C(5,5) = 10 + 10 + 5 + 1 = 26
      expect(subsets.length, equals(26));
    });
  });
}
