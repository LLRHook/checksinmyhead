import 'dart:io';

import 'package:checks_frontend/database/database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'save_receipt_test.dart' show Harness;

void main() {
  test(
    'new receipt uses insertion time instead of historical table default',
    () async {
      final sql = File('test/fixtures/drift9_identity.sql').readAsStringSync();
      final db = AppDatabase.forTesting(
        NativeDatabase.memory(setup: (raw) => raw.execute(sql)),
      );
      final h = Harness(database: db)..replay = false;
      addTearDown(db.close);
      final before = DateTime.now().subtract(const Duration(seconds: 1));
      final result = await h.save('timestamp');
      final row = (await db.getBillById(result.localId))!;
      expect(row.createdAt.isAfter(before), isTrue);
      expect(
        row.createdAt.isBefore(DateTime.now().add(const Duration(seconds: 1))),
        isTrue,
      );
      expect(row.createdAt.millisecondsSinceEpoch ~/ 1000, isNot(1793912155));
      expect(row.creationSnapshot, isNotNull);
      expect(h.posts, 0);
    },
  );
}
