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
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

/// SettingsScreen
///
/// A configurable settings screen that handles both initial onboarding setup and
/// subsequent configuration of payment methods and app preferences.
///
/// This screen provides functionality for:
/// - Adding, editing, and removing payment methods for receiving money
/// - Viewing privacy information
/// - Contacting support
/// - Rating the app
/// - Sharing the app with friends
///
/// The screen has two modes controlled by the isOnboarding parameter:
/// - Onboarding mode: Focused on payment setup with limited navigation options
/// - Regular mode: Full settings experience with additional support options
///
/// All settings are persisted locally using SharedPreferences for privacy.
class SettingsScreen extends StatefulWidget {
  /// Controls whether the screen is shown during initial onboarding
  /// or as a regular settings page
  final bool isOnboarding;

  const SettingsScreen({super.key, this.isOnboarding = false});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  /// Available payment methods that can be configured
  final List<String> _paymentOptions = [
    'Venmo',
    'Zelle',
    'Apple Pay',
    'PayPal',
    'Cash App',
  ];

  /// Map storing the user identifier for each payment method
  /// Key: Payment method name, Value: User identifier
  final Map<String, String> _paymentIdentifiers = {};

  /// Input field hints for different payment methods to guide users
  final Map<String, String> _paymentHints = {
    'Venmo': '@username',
    'PayPal': 'PayPal email/username',
    'Cash App': '\$cashtag',
    'Zelle': 'Zelle phone number/email',
    'Apple Pay': 'Phone number',
  };

  /// List of payment methods the user has selected to use
  List<String> _selectedPayments = [];

  @override
  void initState() {
    super.initState();

    // Load saved payment preferences when screen initializes
    _loadPaymentSettings();

    // Automatically show payment selection when in onboarding mode
    if (widget.isOnboarding) {
      // Wait for the first frame to be rendered, then show the modal
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showPaymentSelection();
      });
    }
  }

  /// Loads saved payment preferences from persistent storage
  ///
  /// This method retrieves:
  /// - List of selected payment methods
  /// - User identifiers for each payment method
  Future<void> _loadPaymentSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // Get list of payment methods or empty list if none found
    final savedPayments = prefs.getStringList('selectedPayments') ?? [];

    // Load identifiers for each payment method
    final Map<String, String> savedIdentifiers = {};
    for (final method in _paymentOptions) {
      final identifier = prefs.getString('payment_$method');
      if (identifier != null && identifier.isNotEmpty) {
        savedIdentifiers[method] = identifier;
      }
    }

    // Update state with retrieved values
    setState(() {
      _selectedPayments = savedPayments;
      _paymentIdentifiers.addAll(savedIdentifiers);
    });
  }

  /// Persists payment preferences to persistent storage
  ///
  /// This method saves:
  /// - List of selected payment methods
  /// - User identifiers for each payment method
  /// - Onboarding status (if applicable)
  Future<void> _savePaymentSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // Save list of selected payment methods
    await prefs.setStringList('selectedPayments', _selectedPayments);

    // Save identifiers for each payment method
    for (final entry in _paymentIdentifiers.entries) {
      await prefs.setString('payment_${entry.key}', entry.value);
    }

    // Mark onboarding as complete if this is onboarding mode
    if (widget.isOnboarding) {
      await prefs.setBool('is_first_launch', false);
    }

    // Show confirmation if widget is still mounted
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment settings saved'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      HapticFeedback.selectionClick(); // Provide tactile feedback
    }
  }

  /// Shows the payment method selection and configuration sheet
  ///
  /// This modal allows users to:
  /// - View all available payment options
  /// - Add new payment methods
  /// - Edit existing payment methods
  /// - Delete payment methods
  void _showPaymentSelection() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      isDismissible:
          !widget.isOnboarding, // Prevent dismissal during onboarding
      enableDrag: !widget.isOnboarding, // Prevent dragging during onboarding
      builder: (context) {
        // Use StatefulBuilder to manage state within the modal
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 20,
                  horizontal: 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title section
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Text(
                        'Set Up Payment Methods',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    // Description (only shown during onboarding)
                    widget.isOnboarding
                        ? const Padding(
                          padding: EdgeInsets.only(bottom: 16),
                          child: Text(
                            'Add your payment info to help friends send you money when splitting bills.',
                            style: TextStyle(fontSize: 14),
                          ),
                        )
                        : const SizedBox.shrink(),

                    // Payment methods list
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _paymentOptions.length,
                        itemBuilder: (context, index) {
                          final option = _paymentOptions[index];
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
                                        ? Text(
                                          _paymentIdentifiers[option] ?? '',
                                        )
                                        : null,
                                // Show action buttons for selected methods
                                trailing:
                                    isSelected
                                        ? Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            // Edit button
                                            IconButton(
                                              icon: const Icon(
                                                Icons.edit,
                                                color: Color(0xFF627D98),
                                              ),
                                              onPressed: () {
                                                _showIdentifierInput(
                                                  option,
                                                  setModalState,
                                                );
                                              },
                                            ),
                                            // Delete button
                                            IconButton(
                                              icon: const Icon(
                                                Icons.delete,
                                                color: Colors.redAccent,
                                              ),
                                              onPressed: () {
                                                setModalState(() {
                                                  _selectedPayments.remove(
                                                    option,
                                                  );
                                                  _paymentIdentifiers.remove(
                                                    option,
                                                  );
                                                });
                                                setState(
                                                  () {},
                                                ); // Update parent state
                                              },
                                            ),
                                          ],
                                        )
                                        : null,
                                onTap: () {
                                  if (isSelected) {
                                    // Show options menu for existing method
                                    _showPaymentMethodOptions(
                                      option,
                                      setModalState,
                                    );
                                  } else {
                                    // Direct to input for new method
                                    _showIdentifierInput(option, setModalState);
                                  }
                                },
                              ),
                              // Add divider between items except the last one
                              if (index < _paymentOptions.length - 1)
                                const Divider(height: 1),
                            ],
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Save button
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          // Save settings and handle navigation
                          _savePaymentSettings();

                          // Navigate to main screen if onboarding is complete
                          // and at least one payment method is configured
                          if (widget.isOnboarding &&
                              _selectedPayments.isNotEmpty) {
                            Navigator.of(
                              context,
                            ).pushReplacementNamed('/landing');
                          } else {
                            Navigator.pop(context); // Just close the modal
                          }
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).brightness == Brightness.dark
                                  ? const Color(0xFF627D98)
                                  : Colors.white,
                          foregroundColor:
                              Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white
                                  : Theme.of(context).colorScheme.primary,
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          widget.isOnboarding ? 'Continue' : 'Save',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Displays action menu for an existing payment method
  ///
  /// This modal shows options to edit or delete a configured payment method
  ///
  /// Parameters:
  /// - paymentMethod: The name of the payment method to show options for
  /// - setModalState: State setter function to update the parent modal
  void _showPaymentMethodOptions(
    String paymentMethod,
    StateSetter setModalState,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Edit option
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit'),
                onTap: () {
                  Navigator.pop(context);
                  _showIdentifierInput(paymentMethod, setModalState);
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
                  setModalState(() {
                    _selectedPayments.remove(paymentMethod);
                    _paymentIdentifiers.remove(paymentMethod);
                  });
                  setState(() {}); // Update parent state
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// Shows input field for entering/editing a payment identifier
  ///
  /// This modal provides an appropriate input field based on the payment method,
  /// pre-filled with existing data if available.
  ///
  /// Parameters:
  /// - paymentMethod: The name of the payment method to configure
  /// - setModalState: State setter function to update the parent modal
  void _showIdentifierInput(String paymentMethod, StateSetter setModalState) {
    // Create controller with existing value if available
    final TextEditingController controller = TextEditingController();
    controller.text = _paymentIdentifiers[paymentMethod] ?? '';

    // Select appropriate keyboard type based on payment method
    TextInputType keyboardType = TextInputType.text;

    if (paymentMethod == 'Zelle' || paymentMethod == 'Apple Pay') {
      keyboardType = TextInputType.phone;
    } else if (paymentMethod == 'PayPal' ||
        paymentMethod == 'Venmo' ||
        paymentMethod == 'Cash App') {
      keyboardType = TextInputType.emailAddress;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allow modal to resize with keyboard
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
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
              // Title
              Text(
                'Set Up $paymentMethod',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // Input field with appropriate keyboard type and hint
              TextField(
                controller: controller,
                keyboardType: keyboardType,
                autofocus: true, // Automatically show keyboard
                style: TextStyle(
                  color:
                      Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black,
                ),
                decoration: InputDecoration(
                  hintText: _paymentHints[paymentMethod],
                  filled: true,
                  fillColor:
                      Theme.of(context).brightness == Brightness.dark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
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
                  onPressed: () {
                    final value = controller.text.trim();
                    setModalState(() {
                      if (value.isNotEmpty) {
                        // Add method to selected list if not already there
                        if (!_selectedPayments.contains(paymentMethod)) {
                          _selectedPayments.add(paymentMethod);
                        }
                        // Save the identifier
                        _paymentIdentifiers[paymentMethod] = value;
                      }
                    });
                    setState(() {}); // Update parent state
                    Navigator.pop(context);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF627D98)
                            : Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Save',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  /// Opens the app store page for leaving a rating
  ///
  /// This method launches the device's app store to the app's page,
  /// allowing users to leave a review.
  Future<void> _openAppStore() async {
    final Uri url = Uri.parse(
      'https://apps.apple.com/app/yourappid',
    ); // TODO: Replace with actual app ID
    if (!await launchUrl(url)) {
      throw Exception('Could not launch $url');
    }
  }

  /// Opens the device's share sheet to share the app
  ///
  /// This method allows users to share information about the app
  /// through their preferred sharing method.
  Future<void> _shareApp() async {
    const String appStoreLink = 'https://apps.apple.com/app/yourappid';
    // TODO: Replace with actual app ID
    const String shareText =
        'Check out Checkmate, the easiest way to split bills with friends! $appStoreLink';

    const String subject = 'Try Checkmate!';

    // Launch the system share sheet
    SharePlus.instance.share(ShareParams(text: shareText, subject: subject));
  }

  @override
  Widget build(BuildContext context) {
    // Extract theme data for adaptive styling
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colorScheme.primary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Settings',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        // Only show back button in regular mode
        automaticallyImplyLeading: !widget.isOnboarding,
        // Only show skip button in onboarding mode (currently empty)
        actions:
            widget.isOnboarding
                ? [
                  TextButton(
                    onPressed: () async {
                      // Skip payment setup and go to main screen
                      final prefs = await SharedPreferences.getInstance();
                      prefs.setBool('is_first_launch', false);

                      // Check if widget is still mounted
                      if (context.mounted) {
                        Navigator.of(context).pushReplacementNamed('/landing');
                      }
                    },
                    child: const Text(
                      '',
                    ), // Empty skip button - should have text
                  ),
                ]
                : null,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // App branding section
                const Center(
                  child: Column(
                    children: [
                      Text(
                        'Checkmate',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.37,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Made by a few friends tired of using\nspreadsheets to split the bill.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // Payment methods section - card with either add button or list of methods
                Container(
                  decoration: BoxDecoration(
                    color:
                        isDark
                            ? colorScheme.surfaceContainerHighest
                            : Colors.white.withValues(alpha: .15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section header
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Payment Options',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Show "Add Payment Methods" button if none exist
                      _selectedPayments.isEmpty
                          ? Padding(
                            padding: const EdgeInsets.all(16),
                            child: FilledButton(
                              onPressed: _showPaymentSelection,
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: colorScheme.primary,
                                minimumSize: const Size.fromHeight(50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Add Payment Methods',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          )
                          // Otherwise show list of configured methods
                          : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _selectedPayments.length,
                            separatorBuilder:
                                (context, index) => const Divider(
                                  color: Colors.white24,
                                  height: 1,
                                  indent: 16,
                                  endIndent: 16,
                                ),
                            itemBuilder: (context, index) {
                              final paymentMethod = _selectedPayments[index];
                              final identifier =
                                  _paymentIdentifiers[paymentMethod] ??
                                  'Not set';

                              // Each payment method as dismissible item for swipe deletion
                              return Dismissible(
                                key: Key(paymentMethod),
                                background: Container(
                                  color: Colors.redAccent,
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20.0),
                                  child: const Icon(
                                    Icons.delete,
                                    color: Colors.white,
                                  ),
                                ),
                                direction: DismissDirection.endToStart,
                                // Confirm deletion with dialog
                                confirmDismiss: (direction) async {
                                  return await showDialog(
                                    context: context,
                                    builder: (BuildContext context) {
                                      return AlertDialog(
                                        title: Text('Delete $paymentMethod?'),
                                        actions: <Widget>[
                                          TextButton(
                                            onPressed:
                                                () => Navigator.of(
                                                  context,
                                                ).pop(false),
                                            child: const Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed:
                                                () => Navigator.of(
                                                  context,
                                                ).pop(true),
                                            child: const Text(
                                              'Delete',
                                              style: TextStyle(
                                                color: Colors.redAccent,
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
                                // Handle actual deletion when confirmed
                                onDismissed: (direction) {
                                  setState(() {
                                    _selectedPayments.removeAt(index);
                                    _paymentIdentifiers.remove(paymentMethod);
                                  });
                                  _savePaymentSettings();
                                },
                                child: ListTile(
                                  title: Text(
                                    paymentMethod,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  subtitle: Text(
                                    identifier,
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.7,
                                      ),
                                    ),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.more_horiz,
                                          color: Colors.white70,
                                          size: 20,
                                        ),
                                        onPressed: () {
                                          _showPaymentMethodOptions(
                                            paymentMethod,
                                            (setState) {
                                              // Update state if needed
                                            },
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),

                      // "Edit Payment Methods" button for existing methods
                      if (_selectedPayments.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: OutlinedButton(
                            onPressed: _showPaymentSelection,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.white70),
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Edit Payment Methods',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Privacy information section with expandable details
                Container(
                  decoration: BoxDecoration(
                    color:
                        isDark
                            ? colorScheme.surfaceContainerHighest
                            : Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Theme(
                    data: Theme.of(
                      context,
                    ).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      title: Row(
                        children: [
                          const Icon(
                            Icons.shield_outlined,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Privacy & Data',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      iconColor: Colors.white,
                      collapsedIconColor: Colors.white70,
                      tilePadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      children: [
                        const Text(
                          'Your data never leaves your device. Checkmate is designed with privacy-first principles—zero cloud storage and zero accounts. All information is stored locally and removed completely when you uninstall.',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Support options (only visible in regular settings mode)
                if (!widget.isOnboarding)
                  Container(
                    decoration: BoxDecoration(
                      color:
                          isDark
                              ? colorScheme.surfaceContainerHighest
                              : Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        // Contact support option
                        ListTile(
                          title: const Text(
                            'Contact Us',
                            style: TextStyle(color: Colors.white),
                          ),
                          subtitle: const Text(
                            'checkmateapp@duck.com',
                            style: TextStyle(color: Colors.white70),
                          ),
                          leading: const Icon(
                            Icons.email_outlined,
                            color: Colors.white,
                          ),
                          onTap: () {
                            final currentContext = context;
                            final emailUri = Uri(
                              scheme: 'mailto',
                              path: 'checkmateapp@duck.com',
                            );

                            // Try email app, fallback to clipboard copy
                            canLaunchUrl(emailUri).then((canLaunch) {
                              if (canLaunch) {
                                launchUrl(emailUri);
                              } else {
                                Clipboard.setData(
                                  const ClipboardData(
                                    text: 'checkmateapp@duck.com',
                                  ),
                                ).then((_) {
                                  if (currentContext.mounted) {
                                    ScaffoldMessenger.of(
                                      currentContext,
                                    ).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Email copied to clipboard',
                                        ),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                });
                              }
                            });
                          },
                        ),

                        const Divider(
                          color: Colors.white24,
                          height: 1,
                          indent: 16,
                          endIndent: 16,
                        ),

                        // App store rating option
                        ListTile(
                          title: const Text(
                            'Rate Us on App Store',
                            style: TextStyle(color: Colors.white),
                          ),
                          subtitle: const Text(
                            'Love Checkmate? Let us know!',
                            style: TextStyle(color: Colors.white70),
                          ),
                          leading: const Icon(
                            Icons.star_border_rounded,
                            color: Colors.white,
                          ),
                          onTap: _openAppStore,
                        ),

                        const Divider(
                          color: Colors.white24,
                          height: 1,
                          indent: 16,
                          endIndent: 16,
                        ),

                        // Share app option
                        ListTile(
                          title: const Text(
                            'Share with Friends',
                            style: TextStyle(color: Colors.white),
                          ),
                          subtitle: const Text(
                            'Spread the word!',
                            style: TextStyle(color: Colors.white70),
                          ),
                          leading: const Icon(
                            Icons.ios_share,
                            color: Colors.white,
                          ),
                          onTap: _shareApp,
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 40),

                // Version info
                const Center(
                  child: Text(
                    'Version 1.0.0',
                    style: TextStyle(color: Colors.white60, fontSize: 14),
                  ),
                ),

                // Continue button during onboarding
                if (widget.isOnboarding)
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: FilledButton(
                      onPressed: () {
                        _savePaymentSettings();
                        Navigator.of(context).pushReplacementNamed('/landing');
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: colorScheme.primary,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Continue to App',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
