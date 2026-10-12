// Billington: Privacy-first receipt spliting
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

class SettingsManager {
  static Future<ShareOptions> getShareOptions() async {
    try {
      return await DatabaseProvider.db.getShareOptions();
    } catch (e) {
      debugPrint('Error loading share options: $e');
      return ShareOptions();
    }
  }

  static Future<void> saveShareOptions(ShareOptions options) async {
    try {
      await DatabaseProvider.db.saveShareOptions(options);
    } catch (e) {
      debugPrint('Error saving share options: $e');
    }
  }
}
