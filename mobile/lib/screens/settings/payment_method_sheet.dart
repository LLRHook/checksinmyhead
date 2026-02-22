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

import 'package:checks_frontend/config/theme.dart';
import 'package:checks_frontend/screens/settings/models/payment_method.dart';
import 'package:checks_frontend/screens/settings/utils/formatting_utils.dart';
import 'package:checks_frontend/screens/settings/utils/validation_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A bottom sheet for configuring payment methods
class PaymentMethodSheet extends StatefulWidget {
  /// Whether this sheet is shown during onboarding
  final bool isOnboarding;

  /// The initially selected payment methods
  final List<String> initialSelectedMethods;

  /// A map of payment method identifiers
  final Map<String, String> initialIdentifiers;

  /// Callback when settings are saved
  final Function(List<String>, Map<String, String>) onSave;

  /// Callback when sheet is closed
  final VoidCallback? onClose;

  const PaymentMethodSheet({
    super.key,
    this.isOnboarding = false,
    required this.initialSelectedMethods,
    required this.initialIdentifiers,
    required this.onSave,
    this.onClose,
  });

  @override
  State<PaymentMethodSheet> createState() => _PaymentMethodSheetState();
}

class _PaymentMethodSheetState extends State<PaymentMethodSheet>
    with SingleTickerProviderStateMixin {
  /// The list of selected payment methods
  late List<String> _selectedPayments;

  /// The map of identifiers for payment methods
  late Map<String, String> _paymentIdentifiers;

  /// Track if any changes were made
  bool _hasChanges = false;

  @override
  void dispose() {
    if (_hasChanges && widget.onClose != null) {
      widget.onClose!();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    // Initialize selected methods and identifiers from props
    _selectedPayments = List<String>.from(widget.initialSelectedMethods);
    _paymentIdentifiers = Map<String, String>.from(widget.initialIdentifiers);
  }

  @override
  Widget build(BuildContext context) {
    // Calculate theme-aware colors for better appearance in both light/dark modes
    final colorScheme = Theme.of(context).colorScheme;
    // Dark text on bright button in dark mode for better contrast

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: ExcludeSemantics(
                child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
                ),
              ),
            ),

            // Title section
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                widget.isOnboarding
                    ? 'Let\'s Get Set Up!'
                    : 'Edit Your Payment Methods',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // Description (only shown during onboarding)
            Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text(
                widget.isOnboarding
                    ? 'How do you want to receive your money?'
                    : 'Want to make any changes?',
                style: TextStyle(fontSize: 14),
              ),
            ),

            // Payment methods list
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: PaymentMethod.availablePaymentMethods.length,
                itemBuilder: (context, index) {
                  final option = PaymentMethod.availablePaymentMethods[index];
                  final isSelected = _selectedPayments.contains(option);
                  final hasIdentifier =
                      _paymentIdentifiers.containsKey(option) &&
                      _paymentIdentifiers[option]!.isNotEmpty;

                  return Column(
                    children: [
                      ListTile(
                        title: Text(option),
                        // Show identifier as subtitle if available
                        subtitle:
                            hasIdentifier
                                ? Text(_paymentIdentifiers[option] ?? '')
                                : null,
                        // Show action buttons for selected methods
                        trailing:
                            isSelected
                                ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Edit button
                                    IconButton(
                                      icon: Icon(
                                        Icons.edit,
                                        color: colorScheme.primary,
                                      ),
                                      tooltip: 'Edit $option',
                                      onPressed: () {
                                        _showIdentifierInput(option);
                                      },
                                    ),
                                    // Delete button
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.redAccent,
                                      ),
                                      tooltip: 'Remove $option',
                                      onPressed: () {
                                        setState(() {
                                          _selectedPayments.remove(option);
                                          _paymentIdentifiers.remove(option);
                                          _hasChanges = true;
                                        });
                                        // Save changes immediately (without toast)
                                        widget.onSave(
                                          _selectedPayments,
                                          _paymentIdentifiers,
                                        );
                                      },
                                    ),
                                  ],
                                )
                                : null,
                        onTap: () {
                          if (isSelected) {
                            // Show options menu for existing method
                            _showPaymentMethodOptions(option);
                          } else {
                            // Direct to input for new method
                            _showIdentifierInput(option);
                          }
                        },
                      ),
                      // Add divider between items except the last one
                      if (index <
                          PaymentMethod.availablePaymentMethods.length - 1)
                        const Divider(height: 1),
                    ],
                  );
                },
              ),
            ),

            // Add Continue button for onboarding only
            if (widget.isOnboarding)
              Column(
                children: [
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        // Success haptic feedback
                        HapticFeedback.mediumImpact();

                        // Close the sheet
                        Navigator.pop(context);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor:
                            Theme.of(context).brightness == Brightness.dark
                                ? AppTheme.defaultPrimary:
                                 Colors.white,
                        foregroundColor:
                            Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : Theme.of(context).colorScheme.primary,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Continue',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  /// Shows options for an existing payment method
  void _showPaymentMethodOptions(String paymentMethod) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Center(
                child: ExcludeSemantics(
                  child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  ),
                ),
              ),
              // Edit option
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit'),
                onTap: () {
                  Navigator.pop(context);
                  _showIdentifierInput(paymentMethod);
                },
              ),
              // Delete option
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.redAccent),
                title: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.redAccent),
                ),
                onTap: () {
                  Navigator.pop(context); // Close options menu first
                  setState(() {
                    _selectedPayments.remove(paymentMethod);
                    _paymentIdentifiers.remove(paymentMethod);
                    _hasChanges = true;
                  });
                  // Save changes immediately (without toast)
                  widget.onSave(_selectedPayments, _paymentIdentifiers);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// Shows input field for entering/editing a payment identifier
  void _showIdentifierInput(String paymentMethod) {
    // Create controller with existing value if available
    final TextEditingController controller = TextEditingController();
    controller.text = _paymentIdentifiers[paymentMethod] ?? '';

    // State for tracking validation error
    String? errorText;

    // Select appropriate keyboard type based on payment method
    TextInputType keyboardType = TextInputType.text;
    if (PaymentMethod.requiresPhoneNumber(paymentMethod)) {
      keyboardType = TextInputType.phone;
    } else if (paymentMethod == 'PayPal' ||
        paymentMethod == 'Venmo' ||
        paymentMethod == 'Cash App') {
      keyboardType = TextInputType.emailAddress;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allow modal to resize with keyboard
      builder: (context) {
        // Use StatefulBuilder to manage the error state within the modal
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              // Adjust padding to avoid keyboard overlap
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                top: 20,
                left: 16,
                right: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Title
                  Text(
                    'Set Up $paymentMethod',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Input field
                  TextField(
                    controller: controller,
                    keyboardType: keyboardType,
                    autofocus: true, // Automatically show keyboard
                    onChanged: (value) {
                      // Clear error when user types
                      if (errorText != null) {
                        setSheetState(() {
                          errorText = null;
                        });
                      }
                    },
                    inputFormatters:
                        PaymentMethod.requiresPhoneNumber(paymentMethod)
                            ? [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9\(\)\-\s+]'),
                              ),
                            ]
                            : null, // Allow only numbers and formatting for phone numbers
                    style: TextStyle(
                      color:
                          Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black,
                    ),
                    decoration: InputDecoration(
                      hintText: PaymentMethod.hintTextFor(paymentMethod),
                      filled: true,
                      fillColor:
                          Theme.of(context).brightness == Brightness.dark
                              ? Colors.white.withValues(alpha: .1)
                              : Colors.black.withValues(alpha: .05),
                      errorText: errorText,
                      errorStyle: const TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w500,
                      ),
                      // Use explicit borders for all states to ensure they show properly
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            errorText != null
                                ? const BorderSide(
                                  color: Colors.redAccent,
                                  width: 2,
                                )
                                : BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            errorText != null
                                ? const BorderSide(
                                  color: Colors.redAccent,
                                  width: 2,
                                )
                                : BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            errorText != null
                                ? const BorderSide(
                                  color: Colors.redAccent,
                                  width: 2,
                                )
                                : const BorderSide(
                                  color: AppTheme.defaultPrimary,
                                  width: 2,
                                ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        final value = controller.text.trim();

                        // Validate phone numbers
                        if (PaymentMethod.requiresPhoneNumber(paymentMethod) &&
                            !ValidationUtils.isValidPhoneNumber(value)) {
                          // Trigger error haptic feedback
                          HapticFeedback.heavyImpact();

                          // Show error in the input field
                          setSheetState(() {
                            errorText =
                                'Please enter a valid 10-digit phone number';
                          });

                          return; // Don't proceed with saving
                        }

                        if (value.isNotEmpty) {
                          setState(() {
                            // Add method to selected list if not already there
                            if (!_selectedPayments.contains(paymentMethod)) {
                              _selectedPayments.add(paymentMethod);
                            }

                            // Format phone numbers before saving
                            if (PaymentMethod.requiresPhoneNumber(
                              paymentMethod,
                            )) {
                              _paymentIdentifiers[paymentMethod] =
                                  FormattingUtils.formatPhoneNumber(value);
                            } else if (paymentMethod == 'Venmo') {
                              _paymentIdentifiers[paymentMethod] =
                                  FormattingUtils.formatVenmoUsername(value);
                            } else if (paymentMethod == 'Cash App') {
                              _paymentIdentifiers[paymentMethod] =
                                  FormattingUtils.formatCashtag(value);
                            } else {
                              _paymentIdentifiers[paymentMethod] = value;
                            }

                            // Success haptic feedback (feels satisfying)
                            HapticFeedback.mediumImpact();
                            _hasChanges = true;
                          });

                          // Auto-save changes immediately (without toast)
                          widget.onSave(_selectedPayments, _paymentIdentifiers);
                        }

                        Navigator.pop(context);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Done',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// Shows the payment method selection sheet
Future<void> showPaymentMethodSheet({
  required BuildContext context,
  bool isOnboarding = false,
  required List<String> selectedMethods,
  required Map<String, String> identifiers,
  required Function(List<String>, Map<String, String>) onSave,
  VoidCallback? onClose,
}) async {
  return showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    isScrollControlled: true,
    isDismissible: !isOnboarding, // Prevent dismissal during onboarding
    enableDrag: !isOnboarding, // Prevent dragging during onboarding
    builder: (context) {
      return PaymentMethodSheet(
        isOnboarding: isOnboarding,
        initialSelectedMethods: selectedMethods,
        initialIdentifiers: identifiers,
        onSave: onSave,
        onClose: onClose,
      );
    },
  );
}

/// Directly shows the identifier input dialog for a specific payment method
Future<void> showPaymentMethodEditor({
  required BuildContext context,
  required String paymentMethod,
  required List<String> selectedMethods,
  required Map<String, String> identifiers,
  required Function(List<String>, Map<String, String>) onSave,
}) async {
  // Create controller with existing value if available
  final TextEditingController controller = TextEditingController();
  controller.text = identifiers[paymentMethod] ?? '';

  // State for tracking validation error
  String? errorText;

  // Select appropriate keyboard type based on payment method
  TextInputType keyboardType = TextInputType.text;
  if (PaymentMethod.requiresPhoneNumber(paymentMethod)) {
    keyboardType = TextInputType.phone;
  } else if (paymentMethod == 'PayPal' ||
      paymentMethod == 'Venmo' ||
      paymentMethod == 'Cash App') {
    keyboardType = TextInputType.emailAddress;
  }

  return showModalBottomSheet(
    context: context,
    isScrollControlled: true, // Allow modal to resize with keyboard
    builder: (context) {
      // Use StatefulBuilder to manage the error state within the modal
      return StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            // Adjust padding to avoid keyboard overlap
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              top: 20,
              left: 16,
              right: 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Title
                Text(
                  'Set Up $paymentMethod',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                // Input field
                TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  autofocus: true, // Automatically show keyboard
                  onChanged: (value) {
                    // Clear error when user types
                    if (errorText != null) {
                      setSheetState(() {
                        errorText = null;
                      });
                    }
                  },
                  inputFormatters:
                      PaymentMethod.requiresPhoneNumber(paymentMethod)
                          ? [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9\(\)\-\s+]'),
                            ),
                          ]
                          : null, // Allow only numbers and formatting for phone numbers
                  style: TextStyle(
                    color:
                        Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black,
                  ),
                  decoration: InputDecoration(
                    hintText: PaymentMethod.hintTextFor(paymentMethod),
                    filled: true,
                    fillColor:
                        Theme.of(context).brightness == Brightness.dark
                            ? Colors.white.withValues(alpha: .1)
                            : Colors.black.withValues(alpha: .05),
                    errorText: errorText,
                    errorStyle: const TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w500,
                    ),
                    // Use explicit borders for all states to ensure they show properly
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          errorText != null
                              ? const BorderSide(
                                color: Colors.redAccent,
                                width: 2,
                              )
                              : BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          errorText != null
                              ? const BorderSide(
                                color: Colors.redAccent,
                                width: 2,
                              )
                              : BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          errorText != null
                              ? const BorderSide(
                                color: Colors.redAccent,
                                width: 2,
                              )
                              : const BorderSide(
                                color: AppTheme.defaultPrimary,
                                width: 2,
                              ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Done button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      final value = controller.text.trim();

                      // Validate phone numbers
                      if (PaymentMethod.requiresPhoneNumber(paymentMethod) &&
                          !ValidationUtils.isValidPhoneNumber(value)) {
                        // Trigger error haptic feedback
                        HapticFeedback.heavyImpact();

                        // Show error in the input field
                        setSheetState(() {
                          errorText =
                              'Please enter a valid 10-digit phone number';
                        });

                        return; // Don't proceed with saving
                      }

                      final updatedMethods = List<String>.from(selectedMethods);
                      final updatedIdentifiers = Map<String, String>.from(
                        identifiers,
                      );

                      if (value.isNotEmpty) {
                        // Add method to selected list if not already there
                        if (!updatedMethods.contains(paymentMethod)) {
                          updatedMethods.add(paymentMethod);
                        }

                        // Format phone numbers before saving
                        if (PaymentMethod.requiresPhoneNumber(paymentMethod)) {
                          updatedIdentifiers[paymentMethod] =
                              FormattingUtils.formatPhoneNumber(value);
                        } else if (paymentMethod == 'Venmo') {
                          updatedIdentifiers[paymentMethod] =
                              FormattingUtils.formatVenmoUsername(value);
                        } else if (paymentMethod == 'Cash App') {
                          updatedIdentifiers[paymentMethod] =
                              FormattingUtils.formatCashtag(value);
                        } else {
                          updatedIdentifiers[paymentMethod] = value;
                        }

                        // Success haptic feedback (feels satisfying)
                        HapticFeedback.mediumImpact();

                        // Save changes
                        onSave(updatedMethods, updatedIdentifiers);
                      }

                      Navigator.pop(context);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Done',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      );
    },
  );
}
