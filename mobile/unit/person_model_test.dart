import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:checks_frontend/models/person.dart';

void main() {
  group('Person model tests', () {
    test('Person constructor creates instance with correct properties', () {
      final person = Person(name: 'Alice', color: Colors.blue);

      expect(person.name, 'Alice');
      expect(person.color, Colors.blue);
    });

    test('Person equality compares name case-insensitively', () {
      final person1 = Person(name: 'Alice', color: Colors.blue);
      final person2 = Person(name: 'alice', color: Colors.blue);
      final person3 = Person(name: 'Bob', color: Colors.blue);

      expect(person1 == person2, true);
      expect(person1 == person3, false);
    });

    test('Person equality compares colors using toARGB32', () {
      final person1 = Person(name: 'Alice', color: Colors.blue);
      final person2 = Person(name: 'Alice', color: Colors.blue);
      final person3 = Person(name: 'Alice', color: Colors.red);

      expect(person1 == person2, true);
      expect(person1 == person3, false);
    });

    test('Person hashCode provides consistent results', () {
      final person1 = Person(name: 'Alice', color: Colors.blue);
      final person2 = Person(name: 'alice', color: Colors.blue);

      expect(person1.hashCode == person2.hashCode, true);
    });

    test('Person with same properties has same hashCode', () {
      final person1 = Person(name: 'Alice', color: Colors.blue);
      final person2 = Person(name: 'Alice', color: Colors.blue);

      expect(person1.hashCode, person2.hashCode);
    });

    test('Person with different properties has different hashCode', () {
      final person1 = Person(name: 'Alice', color: Colors.blue);
      final person2 = Person(name: 'Bob', color: Colors.blue);
      final person3 = Person(name: 'Alice', color: Colors.red);

      expect(person1.hashCode != person2.hashCode, true);
      expect(person1.hashCode != person3.hashCode, true);
    });

    test('Person can be used as map key correctly', () {
      final alice = Person(name: 'Alice', color: Colors.blue);
      final aliceDuplicate = Person(name: 'alice', color: Colors.blue);
      final bob = Person(name: 'Bob', color: Colors.red);

      final map = <Person, String>{};
      map[alice] = 'Alice Value';
      map[bob] = 'Bob Value';

      expect(map[alice], 'Alice Value');
      expect(
        map[aliceDuplicate],
        'Alice Value',
      ); // Should find by case-insensitive name
      expect(map[bob], 'Bob Value');
      expect(map.length, 2); // Only 2 entries should exist
    });
  });
}
