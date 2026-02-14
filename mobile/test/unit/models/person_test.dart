import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:checks_frontend/models/person.dart';

void main() {
  group('Person equality', () {
    test('identical objects are equal', () {
      final person = Person(name: 'Alice', color: Colors.blue);
      expect(person == person, isTrue);
    });

    test('same name and color are equal', () {
      final a = Person(name: 'Alice', color: Colors.blue);
      final b = Person(name: 'Alice', color: Colors.blue);
      expect(a, equals(b));
    });

    test('equality is case-insensitive on name', () {
      final a = Person(name: 'alice', color: Colors.blue);
      final b = Person(name: 'Alice', color: Colors.blue);
      expect(a, equals(b));
    });

    test('different names are not equal', () {
      final a = Person(name: 'Alice', color: Colors.blue);
      final b = Person(name: 'Bob', color: Colors.blue);
      expect(a, isNot(equals(b)));
    });

    test('different colors are not equal', () {
      final a = Person(name: 'Alice', color: Colors.blue);
      final b = Person(name: 'Alice', color: Colors.red);
      expect(a, isNot(equals(b)));
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
      final b = Person(name: 'Alice', color: Colors.blue);
      expect(a.hashCode, equals(b.hashCode));
    });

    test('case-insensitive names produce same hash code', () {
      final a = Person(name: 'alice', color: Colors.blue);
      final b = Person(name: 'ALICE', color: Colors.blue);
      expect(a.hashCode, equals(b.hashCode));
    });

    test('works correctly in a Set', () {
      final a = Person(name: 'Alice', color: Colors.blue);
      final b = Person(name: 'alice', color: Colors.blue);
      final set = {a, b};
      expect(set.length, equals(1));
    });

    test('works correctly as Map key', () {
      final a = Person(name: 'Alice', color: Colors.blue);
      final b = Person(name: 'alice', color: Colors.blue);
      final map = <Person, int>{a: 1};
      map[b] = 2;
      expect(map.length, equals(1));
      expect(map[a], equals(2));
    });
  });
}
