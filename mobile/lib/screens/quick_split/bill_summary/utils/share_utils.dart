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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '/models/person.dart';
import '/models/bill_item.dart';
import 'calculation_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ShareUtils - Utility for generating and sharing bill summaries
///
/// Contains methods for retrieving payment information, generating formatted
/// bill summary text (with multiple options), and sharing the summary with others.
class ShareUtils {
  /// Retrieves payment method information from shared preferences
  static Future<Map<String, dynamic>> getPaymentInfo() async {
    final prefs = await SharedPreferences.getInstance();

    final selectedPayments = prefs.getStringList('selectedPayments') ?? [];

    final Map<String, String> paymentIdentifiers = {};
    for (final method in selectedPayments) {
      final identifier = prefs.getString('payment_$method');
      if (identifier != null && identifier.isNotEmpty) {
        paymentIdentifiers[method] = identifier;
      }
    }

    return {
      'selectedPayments': selectedPayments,
      'paymentIdentifiers': paymentIdentifiers,
    };
  }

  /// Generates formatted text for bill summary with person-based lookups
  static Future<String> generateShareText({
    required List<Person> participants,
    required Map<Person, double> personShares,
    required List<BillItem> items,
    required double subtotal,
    required double tax,
    required double tipAmount,
    required double total,
    required Person? birthdayPerson,
    required double tipPercentage,
    required bool isCustomTipAmount,
    required bool includeItemsInShare,
    required bool includePersonItemsInShare,
    required bool hideBreakdownInShare,
    String? billName,
  }) async {
    // Sort participants by payment amount (highest first)
    final sortedParticipants = List<Person>.from(participants);
    sortedParticipants.sort((a, b) {
      final aShare = personShares[a] ?? 0;
      final bShare = personShares[b] ?? 0;
      return bShare.compareTo(aShare);
    });

    // Get payment information
    final paymentInfo = await getPaymentInfo();
    final selectedPayments = paymentInfo['selectedPayments'] as List<String>;
    final paymentIdentifiers =
        paymentInfo['paymentIdentifiers'] as Map<String, String>;

    StringBuffer text = StringBuffer();

    // Add bill name if provided
    if (billName != null && billName.isNotEmpty) {
      text.writeln(billName.toUpperCase());
      text.writeln('───────────────');
    }

    text.writeln('BILL SUMMARY');
    text.writeln('Total: \$${total.toStringAsFixed(2)}');
    text.writeln('───────────────');

    if (includeItemsInShare && items.isNotEmpty) {
      text.writeln('ITEMS:');
      for (var item in items) {
        text.writeln('• ${item.name}: \$${item.price.toStringAsFixed(2)}');
      }
      text.writeln('───────────────');
    }

    if (!hideBreakdownInShare) {
      text.writeln('BREAKDOWN:');
      text.writeln('Subtotal: \$${subtotal.toStringAsFixed(2)}');
      text.writeln('Tax: \$${tax.toStringAsFixed(2)}');

      if (isCustomTipAmount) {
        text.writeln('Tip: \$${tipAmount.toStringAsFixed(2)}');
      } else {
        text.writeln(
          'Tip (${tipPercentage.toStringAsFixed(0)}%): \$${tipAmount.toStringAsFixed(2)}',
        );
      }

      text.writeln('───────────────');
    }

    text.writeln('INDIVIDUAL SHARES:');

    bool anySharesWritten = false;

    for (var person in sortedParticipants) {
      final share = personShares[person] ?? 0;

      if (share > 0 || person == birthdayPerson) {
        anySharesWritten = true;
        if (person == birthdayPerson) {
          text.writeln('• 🎂 ${person.name}: \$${share.toStringAsFixed(2)}');
        } else {
          text.writeln('• ${person.name}: \$${share.toStringAsFixed(2)}');
        }

        if (includePersonItemsInShare && items.isNotEmpty) {
          // Use calculation utils to get personal breakdown
          final amounts = CalculationUtils.calculatePersonAmounts(
            person: person,
            participants: participants,
            personShares: personShares,
            items: items,
            subtotal: subtotal,
            tax: tax,
            tipAmount: tipAmount,
            birthdayPerson: birthdayPerson,
          );
          List<String> personItems = [];

          for (var item in items) {
            if (item.assignments.containsKey(person) &&
                item.assignments[person]! > 0) {
              double percentage = item.assignments[person]! / 100.0;
              double amount = item.price * percentage;

              String sharedText = "";
              if (percentage < 0.99) {
                sharedText = " (shared)";
              }

              personItems.add(
                "  - ${item.name}: \$${amount.toStringAsFixed(2)}$sharedText",
              );
            }
          }

          if (personItems.isNotEmpty) {
            for (var itemText in personItems) {
              text.writeln(itemText);
            }

            text.writeln(
              '  + Tax & tip: \$${(amounts['tax']! + amounts['tip']!).toStringAsFixed(2)}',
            );

            text.writeln('');
          }
        }
      }
    }

    if (!anySharesWritten) {
      // Keep this as an error log
      debugPrint("ERROR: No individual shares were written!");
    }

    // Add payment details if available
    if (selectedPayments.isNotEmpty && paymentIdentifiers.isNotEmpty) {
      text.writeln('───────────────');
      text.writeln('PAYMENT DETAILS:');

      for (var i = 0; i < selectedPayments.length; i++) {
        final method = selectedPayments[i];
        final identifier = paymentIdentifiers[method];

        if (identifier != null && identifier.isNotEmpty) {
          text.writeln('$method: $identifier');
        }
      }
    }

    text.writeln('───────────────');
    text.writeln('Split with CheckMate');

    return text.toString();
  }

  /// Alternative implementation using name-based lookups for more reliable matching
  /// when Person object equality may fail (e.g., after serialization/deserialization)
  static Future<String> generateShareTextWithNameLookup({
    required List<Person> participants,
    required Map<String, double> personSharesByName,
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
    String? billName,
  }) async {
    // Sort participants by payment amount (highest first)
    final sortedParticipants = List<Person>.from(participants);
    sortedParticipants.sort((a, b) {
      final aShare = personSharesByName[a.name] ?? 0;
      final bShare = personSharesByName[b.name] ?? 0;
      return bShare.compareTo(aShare);
    });

    final paymentInfo = await getPaymentInfo();
    final selectedPayments = paymentInfo['selectedPayments'] as List<String>;
    final paymentIdentifiers =
        paymentInfo['paymentIdentifiers'] as Map<String, String>;

    StringBuffer text = StringBuffer();

    // Add bill name if provided
    if (billName != null && billName.isNotEmpty) {
      text.writeln(billName.toUpperCase());
      text.writeln('───────────────');
    }

    text.writeln('BILL SUMMARY');
    text.writeln('Total: \$${total.toStringAsFixed(2)}');
    text.writeln('───────────────');

    if (includeItemsInShare && items.isNotEmpty) {
      text.writeln('ITEMS:');
      for (var item in items) {
        text.writeln('• ${item.name}: \$${item.price.toStringAsFixed(2)}');
      }
      text.writeln('───────────────');
    }

    if (!hideBreakdownInShare) {
      text.writeln('BREAKDOWN:');
      text.writeln('Subtotal: \$${subtotal.toStringAsFixed(2)}');
      text.writeln('Tax: \$${tax.toStringAsFixed(2)}');

      if (isCustomTipAmount) {
        text.writeln('Tip: \$${tipAmount.toStringAsFixed(2)}');
      } else {
        text.writeln(
          'Tip (${tipPercentage.toStringAsFixed(0)}%): \$${tipAmount.toStringAsFixed(2)}',
        );
      }

      text.writeln('───────────────');
    }

    text.writeln('INDIVIDUAL SHARES:');

    for (var person in sortedParticipants) {
      final share = personSharesByName[person.name] ?? 0;

      if (share > 0) {
        text.writeln('• ${person.name}: \$${share.toStringAsFixed(2)}');

        if (includePersonItemsInShare && items.isNotEmpty) {
          List<String> personItems = [];

          for (var item in items) {
            // Find assignments by matching person name instead of object reference
            bool hasAssignment = false;
            double percentage = 0.0;
            double amount = 0.0;

            item.assignments.forEach((assignedPerson, assignedPercentage) {
              if (assignedPerson.name == person.name &&
                  assignedPercentage > 0) {
                hasAssignment = true;
                percentage = assignedPercentage / 100.0;
                amount = item.price * percentage;
              }
            });

            if (hasAssignment) {
              String sharedText = "";
              if (percentage < 0.99) {
                sharedText = " (shared)";
              }

              personItems.add(
                "  - ${item.name}: \$${amount.toStringAsFixed(2)}$sharedText",
              );
            }
          }

          if (personItems.isNotEmpty) {
            for (var itemText in personItems) {
              text.writeln(itemText);
            }

            if (!hideBreakdownInShare) {
              // Calculate tax and tip based on proportion of total
              final proportion = share / total;
              final taxAndTipPortion = proportion * (tax + tipAmount);

              text.writeln(
                '  + Tax & tip: \$${taxAndTipPortion.toStringAsFixed(2)}',
              );
            }

            text.writeln('');
          }
        }
      }
    }

    if (selectedPayments.isNotEmpty && paymentIdentifiers.isNotEmpty) {
      text.writeln('───────────────');
      text.writeln('PAYMENT DETAILS:');

      for (var i = 0; i < selectedPayments.length; i++) {
        final method = selectedPayments[i];
        final identifier = paymentIdentifiers[method];

        if (identifier != null && identifier.isNotEmpty) {
          text.writeln('$method: $identifier');
        }
      }
    }

    text.writeln('───────────────');
    text.writeln('Split with CheckMate');

    return text.toString();
  }

  /// Shares the bill summary text using the system share sheet
  static void shareBillSummary({required String summary}) {
    SharePlus.instance.share(
      ShareParams(text: summary, subject: 'Bill Summary'),
    );
    // Provide tactile feedback to confirm the action
    HapticFeedback.selectionClick();
  }
}

/// Bottom sheet widget for configuring share options
class ShareOptionsSheet extends StatefulWidget {
  final ShareOptions initialOptions;
  final Function(ShareOptions) onOptionsChanged;
  final VoidCallback onShareTap;

  const ShareOptionsSheet({
    super.key,
    required this.initialOptions,
    required this.onOptionsChanged,
    required this.onShareTap,
  });

  /// Shows this sheet as a modal bottom sheet
  static Future<void> show({
    required BuildContext context,
    required ShareOptions initialOptions,
    required Function(ShareOptions) onOptionsChanged,
    required VoidCallback onShareTap,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => ShareOptionsSheet(
            initialOptions: initialOptions,
            onOptionsChanged: onOptionsChanged,
            onShareTap: onShareTap,
          ),
    );
  }

  @override
  State<ShareOptionsSheet> createState() => _ShareOptionsSheetState();
}

class _ShareOptionsSheetState extends State<ShareOptionsSheet> {
  late ShareOptions _options;

  @override
  void initState() {
    super.initState();
    // Create a copy to avoid modifying the original
    _options = ShareOptions(
      includeItemsInShare: widget.initialOptions.includeItemsInShare,
      includePersonItemsInShare:
          widget.initialOptions.includePersonItemsInShare,
      hideBreakdownInShare: widget.initialOptions.hideBreakdownInShare,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    // Calculate theme-aware colors for better appearance in both light/dark modes
    final sheetBgColor =
        brightness == Brightness.dark ? colorScheme.surface : Colors.white;

    final containerBgColor =
        brightness == Brightness.dark
            ? colorScheme.surfaceContainerHighest
            : Colors.grey.shade50;

    final dividerColor =
        brightness == Brightness.dark
            ? Colors.grey.shade800
            : Colors.grey.shade200;

    final titleColor = colorScheme.onSurface;

    // Dark text on bright button in dark mode for better contrast
    final buttonTextColor =
        brightness == Brightness.dark
            ? Colors.black.withValues(alpha: 0.9)
            : Colors.white;

    return Container(
      color: sheetBgColor,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              Center(
                child: Text(
                  'Share Options',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Container(
                decoration: BoxDecoration(
                  color: containerBgColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: Text(
                        'List all bill items',
                        style: TextStyle(color: colorScheme.onSurface),
                      ),
                      value: _options.includeItemsInShare,
                      activeColor: colorScheme.primary,
                      onChanged: (value) {
                        setState(() {
                          _options.includeItemsInShare = value;
                        });
                        widget.onOptionsChanged(_options);
                      },
                    ),

                    Divider(height: 1, thickness: 1, color: dividerColor),

                    SwitchListTile(
                      title: Text(
                        'Hide breakdown',
                        style: TextStyle(color: colorScheme.onSurface),
                      ),
                      value: _options.hideBreakdownInShare,
                      activeColor: colorScheme.primary,
                      onChanged: (value) {
                        setState(() {
                          _options.hideBreakdownInShare = value;
                        });
                        widget.onOptionsChanged(_options);
                      },
                    ),

                    Divider(height: 1, thickness: 1, color: dividerColor),
                    SwitchListTile(
                      title: Text(
                        'Show each person\'s items',
                        style: TextStyle(color: colorScheme.onSurface),
                      ),
                      value: _options.includePersonItemsInShare,
                      activeColor: colorScheme.primary,
                      onChanged: (value) {
                        setState(() {
                          _options.includePersonItemsInShare = value;
                        });
                        widget.onOptionsChanged(_options);
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  widget.onShareTap();
                },
                icon: const Icon(Icons.ios_share, size: 20),
                label: const Text('Share Bill Summary'),
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: buttonTextColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Model class for share customization options
class ShareOptions {
  bool includeItemsInShare;
  bool includePersonItemsInShare;
  bool hideBreakdownInShare;

  ShareOptions({
    this.includeItemsInShare = true,
    this.includePersonItemsInShare = false,
    this.hideBreakdownInShare = false,
  });
}
