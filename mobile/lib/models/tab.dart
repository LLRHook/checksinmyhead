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
  final String? memberToken;
  final String? role;
  final bool isRemote;

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
    this.memberToken,
    this.role,
    this.isRemote = false,
  });

  bool get isSynced => backendId != null;

  bool get isFinalized => finalized;

  bool get isCreator => role == 'creator';

  bool get isMember => memberToken != null;

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
    String? memberToken,
    String? role,
    bool? isRemote,
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
      memberToken: memberToken ?? this.memberToken,
      role: role ?? this.role,
      isRemote: isRemote ?? this.isRemote,
    );
  }
}
