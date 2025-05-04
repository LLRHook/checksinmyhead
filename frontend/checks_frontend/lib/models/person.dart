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

  // You must override hashCode when overriding ==
  @override
  int get hashCode => name.hashCode ^ color.toARGB32().hashCode;
}
