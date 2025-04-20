import 'package:flutter/material.dart';

class Person {
  final String name;
  final Color color;
  final IconData icon;

  Person({required this.name, required this.color, this.icon = Icons.person});
}
