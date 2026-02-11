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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../models/bill_summary_data.dart';
import '../utils/share_utils.dart';
import 'package:checks_frontend/screens/settings/services/settings_manager.dart';

/// Enhanced share sheet that offers multiple sharing options:
/// 1. Share Link - Opens system share sheet with web link
/// 2. Share Text Receipt - Opens share options modal for customizable text
/// 3. Copy Link - Copies link directly to clipboard
class EnhancedShareSheet extends StatelessWidget {
  final String? shareUrl;
  final BillSummaryData data;

  const EnhancedShareSheet({
    super.key,
    this.shareUrl,
    required this.data,
  });

  /// Shows the enhanced share sheet as a modal bottom sheet
  static Future<void> show({
    required BuildContext context,
    String? shareUrl,
    required BillSummaryData data,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => EnhancedShareSheet(
        shareUrl: shareUrl,
        data: data,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    // Theme-aware colors
    final backgroundColor =
        brightness == Brightness.dark
            ? colorScheme.surfaceContainerHighest
            : Colors.white;

    final cardBgColor =
        brightness == Brightness.dark
            ? colorScheme.surfaceContainerHigh
            : Colors.grey.shade50;

    final iconBgColor =
        brightness == Brightness.dark
            ? colorScheme.primaryContainer.withValues(alpha: 0.3)
            : colorScheme.primaryContainer.withValues(alpha: 0.5);

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Text(
                'Share Bill Summary',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Share Link Option (only if URL exists)
              if (shareUrl != null && shareUrl!.isNotEmpty) ...[
                _buildShareOption(
                  context: context,
                  icon: Icons.link,
                  title: 'Share Link',
                  subtitle: 'Send shareable web link',
                  iconBgColor: iconBgColor,
                  cardBgColor: cardBgColor,
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    Navigator.pop(context);
                    SharePlus.instance.share(
                      ShareParams(
                        text: shareUrl!,
                        subject: '${data.billName} - Bill Summary',
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
              ],

              // Share Text Receipt Option
              _buildShareOption(
                context: context,
                icon: Icons.receipt_long,
                title: 'Share Text Receipt',
                subtitle: 'Send formatted breakdown',
                iconBgColor: iconBgColor,
                cardBgColor: cardBgColor,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  Navigator.pop(context);
                  _showTextShareOptions(context);
                },
              ),

              // Copy Link Option (only if URL exists)
              if (shareUrl != null && shareUrl!.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildShareOption(
                  context: context,
                  icon: Icons.content_copy,
                  title: 'Copy Link',
                  subtitle: 'Copy to clipboard',
                  iconBgColor: iconBgColor,
                  cardBgColor: cardBgColor,
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    Clipboard.setData(ClipboardData(text: shareUrl!));
                    Navigator.pop(context);
                    
                    // Show confirmation snackbar
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.white),
                            SizedBox(width: 10),
                            Text('Link copied to clipboard'),
                          ],
                        ),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        backgroundColor: colorScheme.primary,
                      ),
                    );
                  },
                ),
              ],

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds a single share option card
  Widget _buildShareOption({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconBgColor,
    required Color cardBgColor,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: cardBgColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon container
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              
              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Arrow icon
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Shows the text share options modal
  void _showTextShareOptions(BuildContext context) async {
    final options = await SettingsManager.getShareOptions();

    if (!context.mounted) return;

    ShareOptionsSheet.show(
      context: context,
      initialOptions: options,
      onOptionsChanged: (updatedOptions) {
        SettingsManager.saveShareOptions(updatedOptions);
      },
      onShareTap: () async {
        final summary = await ShareUtils.generateShareText(
          participants: data.participants,
          personShares: data.personShares,
          items: data.items,
          subtotal: data.subtotal,
          tax: data.tax,
          tipAmount: data.tipAmount,
          total: data.total,
          birthdayPerson: data.birthdayPerson,
          tipPercentage: data.tipPercentage,
          isCustomTipAmount: data.isCustomTipAmount,
          showAllItems: options.showAllItems,
          showPersonItems: options.showPersonItems,
          showBreakdown: !options.showBreakdown,
          billName: data.billName,
        );

        ShareUtils.shareBillSummary(summary: summary);
      },
    );
  }
}