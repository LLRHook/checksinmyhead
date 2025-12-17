// mobile/lib/models/tab.dart

class AppTab {
  final int? id;
  final String name;
  final DateTime createdAt;
  final List<int> billIds; // References to RecentBill IDs
  
  AppTab({
    this.id,
    required this.name,
    required this.createdAt,
    required this.billIds,
  });
  
  double getTotalAmount(List<double> billTotals) {
    return billTotals.fold(0.0, (sum, total) => sum + total);
  }
  
  // Helper to serialize/deserialize billIds for storage
  String get billIdsJson => billIds.join(',');
  
  static List<int> parseBillIds(String json) {
    if (json.isEmpty) return [];
    return json.split(',').map((e) => int.parse(e)).toList();
  }
}