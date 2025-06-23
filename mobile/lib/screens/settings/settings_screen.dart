// Spliq: Privacy-first receipt spliting
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

import 'package:checks_frontend/screens/settings/services/preferences_service.dart';
import 'package:checks_frontend/screens/settings/widgets/payment_method_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'payment_method_sheet.dart';
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
  /// List of payment methods the user has selected to use
  List<String> _selectedPayments = [];

  /// Map storing the user identifier for each payment method
  /// Key: Payment method name, Value: User identifier
  Map<String, String> _paymentIdentifiers = {};

  /// Service for handling preferences
  final _prefsService = PreferencesService();

  /// Loading state
  bool _isLoading = true;

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
  Future<void> _loadPaymentSettings() async {
    try {
      // Get selected payment methods
      final savedPayments = await _prefsService.getSelectedPaymentMethods();

      // Load identifiers for each payment method
      final savedIdentifiers = await _prefsService.getAllPaymentIdentifiers();

      // Update state with retrieved values
      setState(() {
        _selectedPayments = savedPayments;
        _paymentIdentifiers = savedIdentifiers;
        _isLoading = false;
      });
    } catch (e) {
      // Handle error
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Something went wrong loading settings'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Persists payment preferences to persistent storage
  Future<void> _savePaymentSettings() async {
    // Save all payment settings
    await _prefsService.saveAllPaymentSettings(
      selectedMethods: _selectedPayments,
      identifiers: _paymentIdentifiers,
    );

    // Show confirmation if widget is still mounted
    if (mounted) {
      HapticFeedback.selectionClick(); // Provide tactile feedback
    }
  }

  /// Completes the onboarding process and navigates to the main app
  Future<void> _completeOnboarding() async {
    // First, save payment settings
    await _savePaymentSettings();

    // Then mark onboarding as complete
    await _prefsService.completeOnboarding();

    // Finally, navigate to the landing page
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/landing');
    }
  }

  /// Shows the payment method selection and configuration sheet
  void _showPaymentSelection() {
    showPaymentMethodSheet(
      context: context,
      isOnboarding: widget.isOnboarding,
      selectedMethods: _selectedPayments,
      identifiers: _paymentIdentifiers,
      onSave: (selectedMethods, identifiers) {
        setState(() {
          _selectedPayments = selectedMethods;
          _paymentIdentifiers = identifiers;
        });
        _savePaymentSettings();
      },
    );
  }

  /// Opens the app store page for leaving a rating
  Future<void> _openAppStore() async {
    final Uri url = Uri.parse(
      'https://apps.apple.com/app/yourappid',
    ); // TODO: Replace with actual app ID
    if (!await launchUrl(url)) {
      throw Exception('Could not launch $url');
    }
  }

  /// Opens the device's share sheet to share the app
  Future<void> _shareApp() async {
    const String appStoreLink = 'https://apps.apple.com/app/yourappid';
    // TODO: Replace with actual app ID
    const String shareText =
        'Check out Spliq, the easiest way to split bills with friends! $appStoreLink';

    const String subject = 'Try Spliq!';

    // Launch the system share sheet
    SharePlus.instance.share(ShareParams(text: shareText, subject: subject));
  }

  @override
  Widget build(BuildContext context) {
    // Extract theme data for adaptive styling
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.primary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title:
            widget.isOnboarding
                ? null
                : const Text(
                  'Settings',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        // Only show back button in regular mode
        automaticallyImplyLeading: !widget.isOnboarding,
        // No skip button (removed for simplicity)
        actions: null,
      ),
      body: SafeArea(
        child:
            _isLoading
                ? const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                )
                : SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // App branding section
                        const Center(
                          child: Column(
                            children: [
                              Text(
                                'Spliq',
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
                            color: Colors.white.withValues(alpha: .15),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Section header
                              const Padding(
                                padding: EdgeInsets.all(16),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
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
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
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
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: _selectedPayments.length,
                                    separatorBuilder:
                                        (context, index) => const Divider(
                                          color: Colors.white24,
                                          height: 1,
                                          indent: 16,
                                          endIndent: 16,
                                        ),
                                    itemBuilder: (context, index) {
                                      final paymentMethod =
                                          _selectedPayments[index];
                                      final identifier =
                                          _paymentIdentifiers[paymentMethod] ??
                                          'Not set';

                                      return PaymentMethodItem(
                                        methodName: paymentMethod,
                                        identifier: identifier,
                                        onEdit: () {
                                          // Show the edit modal directly
                                          showPaymentMethodSheet(
                                            context: context,
                                            selectedMethods: _selectedPayments,
                                            identifiers: _paymentIdentifiers,
                                            onSave: (
                                              selectedMethods,
                                              identifiers,
                                            ) {
                                              setState(() {
                                                _selectedPayments =
                                                    selectedMethods;
                                                _paymentIdentifiers =
                                                    identifiers;
                                              });
                                              _savePaymentSettings();
                                            },
                                          );
                                        },
                                        onDelete: () {
                                          setState(() {
                                            _selectedPayments.remove(
                                              paymentMethod,
                                            );
                                            _paymentIdentifiers.remove(
                                              paymentMethod,
                                            );
                                          });
                                          _savePaymentSettings();
                                        },
                                        onTap: () {
                                          // Show edit screen when tapped
                                          showPaymentMethodSheet(
                                            context: context,
                                            selectedMethods: _selectedPayments,
                                            identifiers: _paymentIdentifiers,
                                            onSave: (
                                              selectedMethods,
                                              identifiers,
                                            ) {
                                              setState(() {
                                                _selectedPayments =
                                                    selectedMethods;
                                                _paymentIdentifiers =
                                                    identifiers;
                                              });
                                              _savePaymentSettings();
                                            },
                                          );
                                        },
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
                                      side: const BorderSide(
                                        color: Colors.white70,
                                      ),
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
                            color: Colors.white.withValues(alpha: .15),
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
                              childrenPadding: const EdgeInsets.fromLTRB(
                                16,
                                0,
                                16,
                                16,
                              ),
                              children: [
                                const Text(
                                  'Your data never leaves your device. Spliq is designed with privacy-first principles—zero cloud storage and zero accounts. All information is stored locally and removed completely when you uninstall.',
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
                              color: Colors.white.withValues(alpha: .15),
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
                                        launchUrl(
                                          emailUri,
                                          mode: LaunchMode.platformDefault,
                                          webOnlyWindowName: '_blank',
                                        );
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
                                    'Love Spliq? Let us know!',
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
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 14,
                            ),
                          ),
                        ),

                        // Continue button during onboarding - now uses the proper method to complete onboarding
                        if (widget.isOnboarding)
                          Padding(
                            padding: const EdgeInsets.only(top: 20),
                            child: FilledButton(
                              onPressed: _completeOnboarding,
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
