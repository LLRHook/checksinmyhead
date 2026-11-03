/// The participant-label contract of POST /api/bills, independent of tab joining.
/// Check the server's sanitized label without changing local/history text.
String? receiptParticipantNameError(String? name) {
  final label = (name ?? '').replaceAll(RegExp(r'<[^>]*>'), '').trim();
  if (label.isEmpty) return 'Please enter a participant name';
  if (label.runes.length > 30) {
    return 'Receipt participant names can use at most 30 Unicode characters. '
        'Use a shorter name for this receipt; saved people and bills are unchanged.';
  }
  return null;
}
