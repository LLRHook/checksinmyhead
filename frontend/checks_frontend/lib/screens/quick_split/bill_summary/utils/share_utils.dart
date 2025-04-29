import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '/models/person.dart';
import '/models/bill_item.dart';
import 'calculation_utils.dart';

class ShareUtils {
  /// Generate text for sharing bill summary
  static String generateShareText({
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
      }
    }

    // App signature - more professional
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
