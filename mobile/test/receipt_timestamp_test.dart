import 'dart:io';

import 'package:checks_frontend/database/database.dart';
import 'package:drift/drift.dart' show Value;
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

  test(
    'explicit receipt timestamp is stored unchanged and an existing handle keeps its row',
    () async {
      final sql = File('test/fixtures/drift9_identity.sql').readAsStringSync();
      final db = AppDatabase.forTesting(
        NativeDatabase.memory(setup: (raw) => raw.execute(sql)),
      );
      final h = Harness(database: db)..replay = false;
      addTearDown(db.close);
      final saved = (await db.getBillById((await h.save('explicit')).localId))!;

      // A caller that supplies a timestamp keeps exactly that timestamp.
      final explicit = DateTime(2020, 1, 2, 3, 4, 5);
      final explicitId = await db.insertReceipt(
        saved
            .toCompanion(false)
            .copyWith(
              id: const Value.absent(),
              creationHandle: const Value('explicit-timestamp-handle'),
              createdAt: Value(explicit),
            ),
      );
      expect(explicitId, isNot(saved.id));
      expect((await db.getBillById(explicitId))!.createdAt, explicit);

      // Presenting an existing handle again returns its row and rewrites nothing.
      final again = await db.insertReceipt(
        saved
            .toCompanion(false)
            .copyWith(
              id: const Value.absent(),
              subtotal: const Value(987654.32),
              createdAt: Value(DateTime(2031, 1, 1)),
            ),
      );
      expect(again, saved.id);
      final unchanged = (await db.getBillById(saved.id))!;
      expect(unchanged.createdAt, saved.createdAt);
      expect(unchanged.toJson(), saved.toJson());
      expect(h.posts, 0);
    },
  );
}
