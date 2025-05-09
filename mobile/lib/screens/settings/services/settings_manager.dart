// Checkmate: Privacy-first receipt spliting
//     Copyright (C) 2025  Kruski Ko.
//     Email us: checkmateapp@duck.com

//     This program is free software: you can redistribute it and/or modify
//     it under the terms of the GNU General Public License as published by
//     the Free Software Foundation, either version 3 of the License, or
//     (at your option) any later version.

//     This program is distributed in the hope that it will be useful,
//     but WITHOUT ANY WARRANTY; without even the implied warranty of
//     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//     GNU General Public License for more details.

//     You should have received a copy of the GNU General Public License
//     along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'package:checks_frontend/database/database_provider.dart';
import 'package:checks_frontend/screens/quick_split/bill_summary/utils/share_utils.dart';
import 'package:flutter/widgets.dart';

/// SettingsManager
///
/// A utility class that provides methods to retrieve and persist user settings.
/// This manager acts as an intermediary between the UI and the database,
/// providing a simplified interface for accessing and updating user preferences.
///
/// Currently, this manager handles share options preferences, which control
/// how bill summaries are shared with others. It provides graceful fallbacks
/// when errors occur to ensure the app continues to function even if settings
/// cannot be loaded.
///
/// Features:
/// - Retrieves saved share options from persistent storage
/// - Saves updated share options to persistent storage
/// - Provides default values when settings cannot be loaded
/// - Handles errors gracefully with appropriate logging
class SettingsManager {
  /// Retrieves the user's saved share options from database
  ///
  /// This method attempts to load the user's previously saved sharing preferences.
  /// If the preferences cannot be loaded (e.g., first run or database error),
  /// it returns default share options to ensure the app can continue functioning.
  ///
  /// Returns:
  /// - The user's saved ShareOptions if successfully loaded
  /// - Default ShareOptions if an error occurs or no settings exist
  static Future<ShareOptions> getShareOptions() async {
    try {
      // Attempt to load saved options from the database
      return await DatabaseProvider.db.getShareOptions();
    } catch (e) {
      // Log the error but don't crash the app
      debugPrint('Error loading share options: $e');

      // Return default values if there's an error
      // This ensures the app can continue functioning even if settings can't be loaded
      return ShareOptions();
    }
  }

  /// Saves the user's share options to database
  ///
  /// This method persists the user's sharing preferences to storage,
  /// allowing them to be restored in future sessions.
  ///
  /// Parameters:
  /// - options: The ShareOptions object containing user preferences to save
  ///
  /// Any errors during saving are caught and logged but not propagated
  /// to the UI to avoid disrupting the user experience.
  static Future<void> saveShareOptions(ShareOptions options) async {
    try {
      // Save the options to the database
      await DatabaseProvider.db.saveShareOptions(options);
    } catch (e) {
      // Log the error but don't crash the app
      debugPrint('Error saving share options: $e');
      // No rethrow - we want to fail silently to avoid disrupting the user
    }
  }
}
