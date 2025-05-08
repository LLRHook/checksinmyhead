// Checkmate: Privacy-first receipt spliting
//     Copyright (C) 2025  Kruski Ko.
//     Email us: checkmateapp@duck.com

//     This program is free software: you can redistribute it and/or modify
//     it under the terms of the GNU General Public License as published by
//     the Free Software Foundation, either version 3 of the License, or
//     (at your option) any later version.

//     This program is distributed in the hope that it will be useful,
//     but WITHOUT ANY WARRANTY; without even the implied warranty of
//     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//     GNU General Public License for more details.

//     You should have received a copy of the GNU General Public License
//     along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'package:flutter/material.dart';

/// A model class representing a person with a name, color, and optional icon.
///
/// This class provides a way to uniquely identify and compare people based on their
/// name and color attributes. The icon property is not considered in equality checks.
///
/// Properties:
/// * [name] - Unique identifier string for the person
/// * [color] - Associated color, typically used for UI representation
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

class Person {
  final String name;
  final Color color;

  Person({required this.name, required this.color});

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
