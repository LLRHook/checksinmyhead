import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '/models/person.dart';
import '/models/bill_item.dart';
import 'calculation_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ShareUtils {
  /// Get payment info from shared preferences
  static Future<Map<String, dynamic>> getPaymentInfo() async {
    final prefs = await SharedPreferences.getInstance();

    // Get selected payment methods
    final selectedPayments = prefs.getStringList('selectedPayments') ?? [];

    // Get identifiers for each payment method
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

  /// Generate text for sharing bill summary
  /// Generate text for sharing bill summary
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
  }) async {
    debugPrint("DEBUG: generateShareText called");
    debugPrint("DEBUG: participants: ${participants.length}");
    debugPrint("DEBUG: personShares: ${personShares.length}");
    debugPrint("DEBUG: items: ${items.length}");

    // Print individual shares
    personShares.forEach((person, amount) {
      debugPrint("DEBUG: SHARE: ${person.name} = $amount");
    });

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
    debugPrint("DEBUG: Writing individual shares section");

    // Debug information about personShares
    if (personShares.isEmpty) {
      debugPrint("DEBUG: WARNING - personShares map is empty!");
    }

    bool anySharesWritten = false;

    for (var person in sortedParticipants) {
      debugPrint("DEBUG: Processing ${person.name}");
      final share = personShares[person] ?? 0;
      debugPrint("DEBUG: Share for ${person.name}: $share");

      if (share > 0 || person == birthdayPerson) {
        anySharesWritten = true;
        // Person's name and share - simplified for everyone including birthday person
        text.writeln('• ${person.name}: \$${share.toStringAsFixed(2)}');
        debugPrint("DEBUG: Added ${person.name} with share $share to summary");

        // Add person-specific items if toggled on
        if (includePersonItemsInShare && items.isNotEmpty) {
          // Calculate the amounts
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
              text.writeln(
                '  + Tax & tip: \$${(amounts['tax']! + amounts['tip']!).toStringAsFixed(2)}',
              );
            }

            // Add a spacer between people
            text.writeln('');
          }
        }
      } else {
        debugPrint("DEBUG: Skipped ${person.name} because share is $share");
      }
    }

    if (!anySharesWritten) {
      debugPrint("DEBUG: WARNING - No individual shares were written!");
    }

    // Payment information (add only if payment options are set)
    if (selectedPayments.isNotEmpty && paymentIdentifiers.isNotEmpty) {
      text.writeln('───────────────');
      text.writeln('PAYMENT DETAILS:');

      // Add each payment method and its identifier
      for (var i = 0; i < selectedPayments.length; i++) {
        final method = selectedPayments[i];
        final identifier = paymentIdentifiers[method];

        if (identifier != null && identifier.isNotEmpty) {
          // If it's the first payment method
          if (i == 0) {
            text.writeln('$method: $identifier');
          }
          // For additional payment methods
          else {
            text.writeln('$method: $identifier');
          }
        }
      }
    }

    // App signature - more professional
    text.writeln('───────────────');
    text.writeln('Split with CheckMate');

    debugPrint("DEBUG: Final share text: ${text.toString()}");

    return text.toString();
  }

  /// Generate text for sharing bill summary using name-based lookups
  static Future<String> generateShareTextWithNameLookup({
    required List<Person> participants,
    required Map<String, double>
    personSharesByName, // Using string keys for reliable lookup
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
  }) async {
    // Sort participants by payment amount (highest first)
    final sortedParticipants = List<Person>.from(participants);
    sortedParticipants.sort((a, b) {
      final aShare = personSharesByName[a.name] ?? 0;
      final bShare = personSharesByName[b.name] ?? 0;
      return bShare.compareTo(aShare);
    });

    // Get payment information
    final paymentInfo = await getPaymentInfo();
    final selectedPayments = paymentInfo['selectedPayments'] as List<String>;
    final paymentIdentifiers =
        paymentInfo['paymentIdentifiers'] as Map<String, String>;

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
      final share = personSharesByName[person.name] ?? 0;

      if (share > 0) {
        // Person's name and share
        text.writeln('• ${person.name}: \$${share.toStringAsFixed(2)}');

        // Add person-specific items if toggled on
        if (includePersonItemsInShare && items.isNotEmpty) {
          List<String> personItems = [];

          for (var item in items) {
            // Find if this person is assigned to this item
            bool hasAssignment = false;
            double percentage = 0.0;
            double amount = 0.0;

            // Check assignments by name - critical change here
            item.assignments.forEach((assignedPerson, assignedPercentage) {
              if (assignedPerson.name == person.name &&
                  assignedPercentage > 0) {
                hasAssignment = true;
                percentage = assignedPercentage / 100.0;
                amount = item.price * percentage;
              }
            });

            if (hasAssignment) {
              // Format shared indicator
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

            // Calculate tax and tip portion
            if (!hideBreakdownInShare) {
              // Simple proportional tax and tip calculation
              final proportion = share / total;
              final taxAndTipPortion = proportion * (tax + tipAmount);

              text.writeln(
                '  + Tax & tip: \$${taxAndTipPortion.toStringAsFixed(2)}',
              );
            }

            // Add a spacer between people
            text.writeln('');
          }
        }
      }
    }

    // Payment information (add only if payment options are set)
    if (selectedPayments.isNotEmpty && paymentIdentifiers.isNotEmpty) {
      text.writeln('───────────────');
      text.writeln('PAYMENT DETAILS:');

      // Add each payment method and its identifier
      for (var i = 0; i < selectedPayments.length; i++) {
        final method = selectedPayments[i];
        final identifier = paymentIdentifiers[method];

        if (identifier != null && identifier.isNotEmpty) {
          text.writeln('$method: $identifier');
        }
      }
    }

    // App signature
    text.writeln('───────────────');
    text.writeln('Split with CheckMate');

    return text.toString();
  }

  /// Share bill summary
  static void shareBillSummary({
    required BuildContext context,
    required String summary,
  }) {
    // Use the SharePlus instance with ShareParams
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

class ShareOptionsSheet extends StatefulWidget {
  final ShareOptions initialOptions;
  final Function(ShareOptions) onOptionsChanged;
  final VoidCallback onShareTap;

  const ShareOptionsSheet({
    Key? key,
    required this.initialOptions,
    required this.onOptionsChanged,
    required this.onShareTap,
  }) : super(key: key);

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
    // Create a copy of the initial options
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

    // Theme-aware colors
    final sheetBgColor =
        brightness == Brightness.dark ? colorScheme.surface : Colors.white;

    final handleColor =
        brightness == Brightness.dark
            ? Colors.grey.shade600
            : Colors.grey.shade300;

    final containerBgColor =
        brightness == Brightness.dark
            ? colorScheme.surfaceContainerHighest
            : Colors.grey.shade50;

    final dividerColor =
        brightness == Brightness.dark
            ? Colors.grey.shade800
            : Colors.grey.shade200;

    final titleColor = colorScheme.onSurface;

    // Button text color - for dark mode, use darker text on bright backgrounds for contrast
    final buttonTextColor =
        brightness == Brightness.dark
            ? Colors.black.withOpacity(0.9) // Dark text for better contrast
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
              // Sheet handle for better UX
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: handleColor,
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

              // Container for all toggles with a subtle background
              Container(
                decoration: BoxDecoration(
                  color: containerBgColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    // First toggle - Include all items
                    SwitchListTile(
                      title: Text(
                        'Include all items',
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

                    // Second toggle - Show each person's items
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

                    Divider(height: 1, thickness: 1, color: dividerColor),

                    // Third toggle - Hide breakdown section
                    SwitchListTile(
                      title: Text(
                        'Hide cost breakdown',
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
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Share button
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
