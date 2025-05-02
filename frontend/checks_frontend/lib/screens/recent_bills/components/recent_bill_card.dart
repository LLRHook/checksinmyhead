import 'package:checks_frontend/screens/recent_bills/billDetails/bill_details_screen.dart';
import 'package:checks_frontend/screens/recent_bills/models/recent_bill_manager.dart';
import 'package:checks_frontend/screens/recent_bills/models/recent_bill_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:checks_frontend/screens/quick_split/bill_entry/utils/currency_formatter.dart';

class RecentBillCard extends StatelessWidget {
  final RecentBillModel bill;
  final VoidCallback onDeleted;

  const RecentBillCard({Key? key, required this.bill, required this.onDeleted})
    : super(key: key);

  // Navigate to bill details screen
  void _navigateToBillDetails(BuildContext context) {
    HapticFeedback.selectionClick();

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => BillDetailsScreen(bill: bill)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final brightness = Theme.of(context).brightness;

    // Theme-aware colors
    final cardBgColor =
        brightness == Brightness.dark ? colorScheme.surface : Colors.white;

    final cardShadowColor =
        brightness == Brightness.dark
            ? Colors.black.withOpacity(0.2)
            : Colors.black.withOpacity(0.04);

    final dividerColor =
        brightness == Brightness.dark
            ? colorScheme.outline.withOpacity(0.2)
            : Colors.grey.shade100;

    final dateColor = colorScheme.onSurface;

    final participantsTextColor =
        brightness == Brightness.dark
            ? colorScheme.onSurface.withOpacity(0.7)
            : colorScheme.onSurface.withOpacity(0.6);

    // Adjust bill color for better visibility in dark mode if needed
    final adjustedBillColor =
        brightness == Brightness.dark
            ? _adjustColorForDarkMode(bill.color)
            : bill.color;

    // Dialog colors
    final dialogBgColor =
        brightness == Brightness.dark ? colorScheme.surface : Colors.white;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: cardShadowColor,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap:
                () =>
                    _navigateToBillDetails(context), // Navigate to bill details
            splashColor: adjustedBillColor.withOpacity(0.1),
            highlightColor: adjustedBillColor.withOpacity(0.05),
            child: Column(
              children: [
                // Main content area
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left - Date and participants
                      Expanded(
                        flex: 6,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Date with formatting
                            Row(
                              children: [
                                Icon(
                                  Icons.event,
                                  size: 16,
                                  color: adjustedBillColor,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  bill.formattedDate,
                                  style: textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: dateColor,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 8),

                            // Participants
                            Row(
                              children: [
                                Icon(
                                  Icons.people_outline,
                                  size: 16,
                                  color: participantsTextColor,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    bill.participantSummary,
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: participantsTextColor,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Right - Total amount in highlighted box
                      Expanded(
                        flex: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color:
                                brightness == Brightness.dark
                                    ? adjustedBillColor.withOpacity(
                                      0.15,
                                    ) // Slightly higher opacity in dark mode
                                    : adjustedBillColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                'Total',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: adjustedBillColor.withOpacity(
                                    brightness == Brightness.dark ? 0.9 : 0.8,
                                  ), // Brighter in dark mode
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  CurrencyFormatter.formatCurrency(bill.total),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: adjustedBillColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Bottom action buttons with subtle divider
                Container(
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: dividerColor, width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      // View button
                      Expanded(
                        child: _buildActionButton(
                          context,
                          icon: Icons.visibility_outlined,
                          label: 'View',
                          onTap: () => _navigateToBillDetails(context),
                          color: colorScheme.primary,
                        ),
                      ),

                      // Vertical divider
                      Container(width: 1, height: 24, color: dividerColor),

                      // Delete button
                      Expanded(
                        child: _buildActionButton(
                          context,
                          icon: Icons.delete_outline,
                          label: 'Delete',
                          onTap:
                              () => _confirmDelete(
                                context,
                                colorScheme,
                                dialogBgColor,
                              ),
                          color: colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    ColorScheme colorScheme,
    Color dialogBgColor,
  ) async {
    HapticFeedback.mediumImpact();

    // Confirm deletion with a premium dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: dialogBgColor,
            title: Row(
              children: [
                Icon(Icons.delete_outline, color: colorScheme.error),
                const SizedBox(width: 8),
                const Text('Delete Bill'),
              ],
            ),
            content: const Text(
              'This bill will be permanently removed from your history.',
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: colorScheme.error),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      await RecentBillsManager.deleteBill(bill.id);

      // Provide haptic feedback for successful deletion
      HapticFeedback.mediumImpact();

      // Refresh the list through callback
      onDeleted();
    }
  }

  // Helper method to adjust colors for better visibility in dark mode
  Color _adjustColorForDarkMode(Color color) {
    // If the color is too dark, brighten it for dark mode
    if (_luminance(color) < 0.4) {
      // Increase the brightness while maintaining hue
      final HSLColor hslColor = HSLColor.fromColor(color);
      return hslColor
          .withLightness((hslColor.lightness + 0.2).clamp(0.0, 1.0))
          .toColor();
    }
    return color;
  }

  // Calculate relative luminance of a color
  double _luminance(Color color) {
    // Formula for relative luminance
    return (0.299 * color.red + 0.587 * color.green + 0.114 * color.blue) / 255;
  }
}
