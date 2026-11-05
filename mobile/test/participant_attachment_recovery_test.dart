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
