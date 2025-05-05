/// A model class representing a person with a name, color, and optional icon.
///
/// This class provides a way to uniquely identify and compare people based on their
/// name and color attributes. The icon property is not considered in equality checks.
///
/// Properties:
/// * [name] - Unique identifier string for the person
/// * [color] - Associated color, typically used for UI representation
/// * [icon] - Optional UI icon, defaults to [Icons.person]
///
/// Notable implementation details:
/// * Custom equality operator implementation using [Color.toARGB32] for reliable color comparison
/// * Proper hashCode implementation maintaining the object equality contract
/// * Immutable design with final fields enforcing proper object state management
///
/// Example usage:
/// ```dart
/// final person = Person(name: "John", color: Colors.blue);
/// ```
library;

import 'package:flutter/material.dart';

class Person {
  final String name;
  final Color color;
  final IconData icon;

  Person({required this.name, required this.color, this.icon = Icons.person});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Person &&
        name == other.name &&
        color.toARGB32() == other.color.toARGB32();
  }

  //If you override ==, you must override hashCode
  @override
  int get hashCode => name.hashCode ^ color.toARGB32().hashCode;
}
