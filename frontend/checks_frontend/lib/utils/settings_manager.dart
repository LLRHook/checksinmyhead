import 'package:checks_frontend/database/database_provider.dart';
import 'package:checks_frontend/screens/quick_split/bill_summary/models/bill_summary_data.dart';

class SettingsManager {
  /// Get the saved share options from database
  static Future<ShareOptions> getShareOptions() async {
    try {
      return await DatabaseProvider.db.getShareOptions();
    } catch (e) {
      print('Error loading share options: $e');
      // Return default values if there's an error
      return ShareOptions();
    }
  }

  /// Save share options to database
  static Future<void> saveShareOptions(ShareOptions options) async {
    try {
      await DatabaseProvider.db.saveShareOptions(options);
    } catch (e) {
      print('Error saving share options: $e');
    }
  }
}
