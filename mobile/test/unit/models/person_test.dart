import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:checks_frontend/models/person.dart';

void main() {
  group('Person equality', () {
    test('identical objects are equal', () {
      final person = Person(name: 'Alice', color: Colors.blue);
      expect(person == person, isTrue);
    });

    test('same name and color are separate receipt occurrences', () {
      final a = Person(name: 'Alice', color: Colors.blue);
      final b = Person(name: 'Alice', color: Colors.blue);
      expect(a, isNot(equals(b)));
    });

    test('case-folded labels remain separate receipt occurrences', () {
      final a = Person(name: 'alice', color: Colors.blue);
      final b = Person(name: 'Alice', color: Colors.blue);
      expect(a, isNot(equals(b)));
    });

    test('different names are not equal', () {
      final a = Person(name: 'Alice', color: Colors.blue);
      final b = Person(name: 'Bob', color: Colors.blue);
      expect(a, isNot(equals(b)));
    });

    test('color and rename preserve a receipt reference', () {
      final a = Person(name: 'Alice', color: Colors.blue);
      final b = a.copyWith(name: 'Renamed', color: Colors.red);
      expect(a, equals(b));
    });

    test('not equal to non-Person object', () {
      final person = Person(name: 'Alice', color: Colors.blue);
      // ignore: unrelated_type_equality_checks
      expect(person == 'Alice', isFalse);
    });
  });

  group('Person hashCode', () {
    test('equal objects have equal hash codes', () {
      final a = Person(name: 'Alice', color: Colors.blue);
      final b = a.copyWith(name: 'Renamed', color: Colors.red);
      expect(a.hashCode, equals(b.hashCode));
    });

    test('server association never changes a receipt hash', () {
      final a = Person(name: 'alice', color: Colors.blue);
      final b = a.copyWith(participantId: 42);
      expect(a.hashCode, equals(b.hashCode));
    });

    test('works correctly in a Set', () {
      final a = Person(name: 'Alice', color: Colors.blue);
      final b = Person(name: 'alice', color: Colors.blue);
      final set = {a, b};
      expect(set.length, equals(2));
    });

    test('works correctly as Map key', () {
      final a = Person(name: 'Alice', color: Colors.blue);
      final b = Person(name: 'alice', color: Colors.blue);
      final map = <Person, int>{a: 1};
      map[b] = 2;
      expect(map.length, equals(2));
      expect(map[a], equals(1));
    });
  });
}
