// Billington: Privacy-first receipt spliting
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

import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';

/// A receipt occurrence. People/groups are suggestions copied into fresh occurrences.
/// Labels and server selectors never determine equality or capability authority.
class Person {
  final String name;
  final Color color;
  final String clientRef;
  final String allocationLabel;
  final int? participantId;
  final int? memberId;

  Person({
    required this.name,
    required this.color,
    String? clientRef,
    String? allocationLabel,
    this.participantId,
    this.memberId,
  }) : clientRef = clientRef ?? newClientRef(),
       allocationLabel = allocationLabel ?? name;

  static String newClientRef() => base64Url
      .encode(List.generate(18, (_) => _random.nextInt(256)))
      .replaceAll('=', '');
  static final _random = Random.secure();

  Person copyWith({String? name, Color? color, int? participantId}) => Person(
    name: name ?? this.name,
    color: color ?? this.color,
    clientRef: clientRef,
    allocationLabel: allocationLabel,
    participantId: participantId ?? this.participantId,
    memberId: memberId,
  );
  Person freshOccurrence() => Person(name: name, color: color);
  String get displayName => name.isEmpty ? 'Unnamed' : name;
  String labelIn(List<Person> roster) =>
      '$displayName · ${roster.indexOf(this) + 1}';
  Map<String, dynamic> toReceiptJson() => {
    'client_ref': clientRef,
    'name': name,
    'allocation_label': allocationLabel,
    'color': color.toARGB32(),
    if (participantId != null) 'participant_id': participantId,
    if (memberId != null) 'member_id': memberId,
  };
  factory Person.fromReceiptJson(Map<String, dynamic> json) => Person(
    name: json['name'] as String,
    color: Color(json['color'] as int? ?? 0xFF2196F3),
    clientRef: json['client_ref'] as String,
    allocationLabel: json['allocation_label'] as String?,
    participantId: json['participant_id'] as int?,
    memberId: json['member_id'] as int?,
  );
  @override
  bool operator ==(Object other) =>
      other is Person && clientRef == other.clientRef;
  @override
  int get hashCode => clientRef.hashCode;
}
