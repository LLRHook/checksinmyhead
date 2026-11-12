import 'package:checks_frontend/database/database.dart';

enum PublicationState { legacy, imported, pending, published, blocked }

enum ValuationState { legacy, pending, native, frozen }

enum AttachmentState { none, pending, attempted, attached }

enum SaveFailure {
  capabilityUnavailable,
  keyAbsent,
  keyLocked,
  keyError,
  unsupportedPlatform,
  contentReview,
  snapshotReview,
  conflict,
  publicationUnavailable,
  invalidResponse,
  checkpointFailed,
  destinationUnavailable,
  attachmentUnknown,
}

class SaveReceiptResult {
  const SaveReceiptResult({
    required this.localId,
    required this.publication,
    required this.valuation,
    required this.attachment,
    this.failure,
    this.shareUrl,
  });
  SaveReceiptResult.fromRow(RecentBill row)
    : localId = row.id,
      publication = PublicationState.values.byName(row.publicationState),
      valuation = ValuationState.values.byName(row.valuationState),
      attachment = AttachmentState.values.byName(row.attachmentState),
      failure =
          row.failureCode == null
              ? null
              : SaveFailure.values.byName(row.failureCode!),
      shareUrl = row.shareUrl;

  final int localId;
  final PublicationState publication;
  final ValuationState valuation;
  final AttachmentState attachment;
  final SaveFailure? failure;
  final String? shareUrl;

  String get message {
    if (publication == PublicationState.legacy ||
        publication == PublicationState.imported) {
      return 'Saved history needs review. It will not be published automatically.';
    }
    if (failure == SaveFailure.keyAbsent) {
      return 'Saved on this device. Recovery key is missing; publication is blocked to prevent a duplicate.';
    }
    if (failure == SaveFailure.keyLocked) {
      return 'Saved on this device. Unlock the device and retry the link.';
    }
    if (failure == SaveFailure.contentReview ||
        failure == SaveFailure.conflict ||
        failure == SaveFailure.snapshotReview) {
      return 'Saved on this device. Publication needs review; no replacement receipt was created.';
    }
    if (publication != PublicationState.published) {
      // Only a stored pending quote is described as a pending conversion: a
      // native USD receipt has nothing to convert.
      return valuation == ValuationState.pending
          ? 'Saved on this device. Link and USD conversion pending.'
          : 'Saved on this device. Link pending.';
    }
    if (attachment == AttachmentState.pending ||
        attachment == AttachmentState.attempted) {
      return 'Link ready. Adding this receipt to the trip is still pending.';
    }
    return 'Saved. Link ready.';
  }
}
