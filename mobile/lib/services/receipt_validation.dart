/// The participant-label contract of POST /api/bills, independent of tab joining.
/// Check the server's sanitized label without changing local/history text.
String? receiptParticipantNameError(String? name) {
  // Match Go strings.TrimSpace (Unicode White_Space). Dart's trim also removes
  // U+FEFF, which the receipt endpoint retains and counts toward the rune limit.
  final label = (name ?? '')
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll(
        RegExp(
          r'^[\u0009-\u000D\u0020\u0085\u00A0\u1680\u2000-\u200A\u2028\u2029\u202F\u205F\u3000]+'
          r'|[\u0009-\u000D\u0020\u0085\u00A0\u1680\u2000-\u200A\u2028\u2029\u202F\u205F\u3000]+$',
        ),
        '',
      );
  if (label.isEmpty) return 'Please enter a participant name';
  if (label.runes.length > 30) {
    return 'Receipt participant names can use at most 30 Unicode characters. '
        'Use a shorter name for this receipt; saved people and bills are unchanged.';
  }
  return null;
}

/// Shared by fresh serialization and raw saved-history publication preflight.
String? receiptAssignmentPercentageError(Object? percentage) {
  if (percentage is! num ||
      !percentage.isFinite ||
      percentage < 0 ||
      percentage > 100) {
    return 'Review item assignments: each percentage must be a finite number '
        'between 0 and 100 before sharing.';
  }
  return null;
}
