// mobile/lib/models/tab.dart

class AppTab {
  final int? id;
  final String name;
  final String description;
  final DateTime createdAt;
  final List<int> billIds; // References to RecentBill IDs
  final int? backendId;
  final String? accessToken;
  final String? shareUrl;
  final bool finalized;

  AppTab({
    this.id,
    required this.name,
    this.description = '',
    required this.createdAt,
    required this.billIds,
    this.backendId,
    this.accessToken,
    this.shareUrl,
    this.finalized = false,
  });

  bool get isSynced => backendId != null;

  bool get isFinalized => finalized;

  double getTotalAmount(List<double> billTotals) {
    return billTotals.fold(0.0, (sum, total) => sum + total);
  }

  // Helper to serialize/deserialize billIds for storage
  String get billIdsJson => billIds.join(',');

  static List<int> parseBillIds(String json) {
    if (json.isEmpty) return [];
    return json.split(',').map((e) => int.parse(e)).toList();
  }

  AppTab copyWith({
    int? id,
    String? name,
    String? description,
    DateTime? createdAt,
    List<int>? billIds,
    int? backendId,
    String? accessToken,
    String? shareUrl,
    bool? finalized,
  }) {
    return AppTab(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      billIds: billIds ?? this.billIds,
      backendId: backendId ?? this.backendId,
      accessToken: accessToken ?? this.accessToken,
      shareUrl: shareUrl ?? this.shareUrl,
      finalized: finalized ?? this.finalized,
    );
  }
}
