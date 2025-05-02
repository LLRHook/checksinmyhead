import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:checks_frontend/models/bill_item.dart';
import 'package:checks_frontend/models/person.dart';
import 'package:checks_frontend/screens/quick_split/bill_summary/models/bill_summary_data.dart';

/// Utilities for sharing bill information
class ShareUtils {
  /// Generate text content for sharing
  static String generateShareText({
    required List<Person> participants,
    required Map<Person, double> personShares,
    required List<BillItem> items,
    required double subtotal,
    required double tax,
    required double tipAmount,
    required double total,
    required double tipPercentage,
    required bool isCustomTipAmount,
    required bool includeItemsInShare,
    required bool includePersonItemsInShare,
    required bool hideBreakdownInShare,
    Person? birthdayPerson,
  }) {
    // Sort participants by payment amount (highest first)
    final sortedParticipants = List<Person>.from(participants);
    sortedParticipants.sort((a, b) {
      final aShare = personShares[a] ?? 0;
      final bShare = personShares[b] ?? 0;
      return bShare.compareTo(aShare);
    });

    // Build the text
    StringBuffer text = StringBuffer();

    // Clean, premium header
    text.writeln('BILL SUMMARY');
    text.writeln('Total: \$${total.toStringAsFixed(2)}');
    text.writeln('───────────────');

    // Items (if toggled on and items exist)
    if (includeItemsInShare && items.isNotEmpty) {
      text.writeln('ITEMS:');
      for (var item in items) {
        text.writeln('• ${item.name}: \$${item.price.toStringAsFixed(2)}');
      }
      text.writeln('───────────────');
    }

    // Breakdown with tip percentage (only if not hidden)
    if (!hideBreakdownInShare) {
      text.writeln('BREAKDOWN:');
      text.writeln('Subtotal: \$${subtotal.toStringAsFixed(2)}');
      text.writeln('Tax: \$${tax.toStringAsFixed(2)}');

      // Display tip differently based on whether it's custom or percentage
      if (isCustomTipAmount) {
        text.writeln('Tip: \$${tipAmount.toStringAsFixed(2)}');
      } else {
        text.writeln(
          'Tip (${tipPercentage.toStringAsFixed(0)}%): \$${tipAmount.toStringAsFixed(2)}',
        );
      }

      text.writeln('───────────────');
    }

    // Individual shares with optional person-specific items
    text.writeln('INDIVIDUAL SHARES:');
    for (var person in sortedParticipants) {
      final share = personShares[person] ?? 0;
      if (share > 0 || person == birthdayPerson) {
        // Person's name and share - simplified for everyone including birthday person
        text.writeln('• ${person.name}: \$${share.toStringAsFixed(2)}');

        // Add person-specific items if toggled on
        if (includePersonItemsInShare && items.isNotEmpty) {
          // Get this person's items
          List<String> personItems = [];

          for (var item in items) {
            // Check if this person is assigned to this item
            if (item.assignments.containsKey(person) &&
                item.assignments[person]! > 0) {
              // Calculate the amount this person is paying for this item
              double percentage = item.assignments[person]! / 100.0;
              double amount = item.price * percentage;

              // Format shared indicator - much simpler now
              String sharedText = "";
              if (percentage < 0.99) {
                sharedText = " (shared)";
              }

              personItems.add(
                "  - ${item.name}: \$${amount.toStringAsFixed(2)}$sharedText",
              );
            }
          }

          // Only add the items section if the person has items
          if (personItems.isNotEmpty) {
            for (var itemText in personItems) {
              text.writeln(itemText);
            }

            // Add tax and tip without repeating the total
            if (!hideBreakdownInShare) {
              // Calculate tax and tip portion for this person
              final double personTotal = personShares[person] ?? 0;
              final double itemsTotal =
                  personItems.isNotEmpty
                      ? calculatePersonItemTotal(person, items)
                      : 0;
              final double taxAndTip = personTotal - itemsTotal;

              if (taxAndTip > 0) {
                text.writeln(
                  '  + Tax & tip: \$${taxAndTip.toStringAsFixed(2)}',
                );
              }
            }

            // Add a spacer between people
            text.writeln('');
          }
        }
      }
    }

    // App signature
    text.writeln('───────────────');
    text.writeln('Split with CheckMate');

    return text.toString();
  }

  /// Calculate the total a person is paying for items
  static double calculatePersonItemTotal(Person person, List<BillItem> items) {
    double total = 0;

    for (var item in items) {
      if (item.assignments.containsKey(person)) {
        double percentage = item.assignments[person]! / 100.0;
        total += item.price * percentage;
      }
    }

    return total;
  }

  /// Share the bill summary using system share dialog
  static Future<void> shareBillSummary({
    required BuildContext context,
    required String summary,
  }) async {
    // Use the share_plus package
    SharePlus.instance
        .share(ShareParams(text: summary, subject: 'Bill Summary'))
        .then((result) {
          // Optionally handle the result
          if (result.status == ShareResultStatus.success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Shared successfully'),
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 2),
              ),
            );
          }
        });

    // Provide haptic feedback
    HapticFeedback.selectionClick();
  }
}

/// Sheet for configuring share options
class ShareOptionsSheet {
  static Future<void> show({
    required BuildContext context,
    required ShareOptions initialOptions,
    required Function(ShareOptions) onOptionsChanged,
    required VoidCallback onShareTap,
  }) async {
    bool includeItems = initialOptions.includeItemsInShare;
    bool includePersonItems = initialOptions.includePersonItemsInShare;
    bool hideBreakdown = initialOptions.hideBreakdownInShare;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setState) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Row(
                      children: [
                        const Text(
                          'Share Options',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Options
                    SwitchListTile(
                      title: const Text('Include items list'),
                      subtitle: const Text('Show all bill items'),
                      value: includeItems,
                      onChanged: (value) {
                        setState(() {
                          includeItems = value;
                          // If items are disabled, also disable person items
                          if (!value) {
                            includePersonItems = false;
                          }
                        });
                      },
                    ),

                    SwitchListTile(
                      title: const Text('Include person-specific items'),
                      subtitle: const Text(
                        'Show which items each person is paying for',
                      ),
                      value: includePersonItems,
                      onChanged:
                          includeItems
                              ? (value) {
                                setState(() {
                                  includePersonItems = value;
                                });
                              }
                              : null,
                    ),

                    SwitchListTile(
                      title: const Text('Hide breakdown'),
                      subtitle: const Text(
                        'Hide subtotal, tax, and tip details',
                      ),
                      value: hideBreakdown,
                      onChanged: (value) {
                        setState(() {
                          hideBreakdown = value;
                        });
                      },
                    ),

                    const SizedBox(height: 24),

                    // Share button
                    ElevatedButton.icon(
                      icon: const Icon(Icons.ios_share),
                      label: const Text('Share Bill Summary'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        // Create new options object
                        final updatedOptions = ShareOptions(
                          includeItemsInShare: includeItems,
                          includePersonItemsInShare: includePersonItems,
                          hideBreakdownInShare: hideBreakdown,
                        );

                        // Notify about options change
                        onOptionsChanged(updatedOptions);

                        // Close sheet
                        Navigator.pop(context);

                        // Trigger share action
                        onShareTap();
                      },
                    ),
                  ],
                ),
              );
            },
          ),
    );
  }
}
