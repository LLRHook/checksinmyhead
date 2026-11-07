import 'package:checks_frontend/database/database.dart';
import 'package:checks_frontend/screens/recent_bills/models/recent_bill_manager.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'save_receipt_test.dart' show Harness;

class AttachmentCheckpointDatabase extends AppDatabase {
  AttachmentCheckpointDatabase() : super.forTesting(NativeDatabase.memory());
  bool fail = false;
  int checkpoints = 0;
  @override
  Future<void> checkpointAttachment(int id, int tabId) async {
    checkpoints++;
    if (fail) throw StateError('synthetic checkpoint uncertainty');
    return super.checkpointAttachment(id, tabId);
  }
}

void main() {
  test(
    'legacy source attach preserves blank long raw labels without rebuilding a create or minting a key',
    () async {
      final db = AttachmentCheckpointDatabase();
      addTearDown(db.close);
      final h = Harness(database: db);
      final tab = await h.tab();
      final id = await db.saveBill(
        participants: [],
        personShares: {},
        items: [],
        subtotal: 5,
        tax: 0,
        tipAmount: 0,
        total: 5,
        shareUrl: 'https://billington.app/b/71?t=original-legacy-source',
      );
      await db.customStatement(
        'UPDATE recent_bills SET participants=?,participant_count=2 WHERE id=?',
        ['["","${'界' * 31}"]', id],
      );
      final before = (await db.getBillById(id))!;
      final result = await h.owner.resumeReceipt(id, intendedTabId: tab);
      expect(result.attachment, AttachmentState.attached);
      expect(h.posts, 0);
      expect(h.attachments, 1);
      expect(h.keys.creates, 0);
      final after = (await db.getBillById(id))!;
      expect(after.participants, before.participants);
      expect(after.total, before.total);
      expect(after.shareUrl, before.shareUrl);
      expect(after.creationHandle, isNull);
      expect(
        h.requests.last.headers.containsKey('X-Billington-Identity-Version'),
        false,
      );
    },
  );
  for (final failure in ['member_denied', 'checkpoint_failed']) {
    test(
      'known attached nonfinalized $failure stops after one reauthorization without fallback POST',
      () async {
        final db = AttachmentCheckpointDatabase();
        addTearDown(db.close);
        final h = Harness(database: db);
        final saved = await h.save();
        final tab = await h.tab();
        await db.checkpointReceipt(
          saved.localId,
          RecentBillsCompanion(
            intendedTabId: Value(tab),
            attachmentState: const Value('attempted'),
          ),
        );
        h.tabRead = {
          'bills': [
            {'id': 19},
          ],
          'finalized': false,
        };
        h.onAttach =
            (_) async =>
                http.Response('{}', failure == 'member_denied' ? 403 : 200);
        db.fail = failure == 'checkpoint_failed';
        final recovered = await h.owner.resumeReceipt(saved.localId);
        expect(h.attachments, 1);
        expect(recovered.attachment, AttachmentState.attempted);
        expect(
          recovered.failure,
          failure == 'member_denied'
              ? SaveFailure.attachmentUnknown
              : SaveFailure.checkpointFailed,
        );
        expect(db.checkpoints, failure == 'member_denied' ? 0 : 1);
        expect((await db.getTabById(tab))!.billIds, '');
        expect(
          (await db.getBillById(saved.localId))!.publicationState,
          'published',
        );
      },
    );
  }
}
