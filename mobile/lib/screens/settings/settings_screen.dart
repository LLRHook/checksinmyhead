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

import 'package:checks_frontend/screens/settings/services/preferences_service.dart';
import 'package:checks_frontend/screens/settings/widgets/payment_method_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'payment_method_sheet.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

/// Settings screen for configuring payment methods and app preferences.
///
/// Provides functionality for:
/// - Adding, editing, and removing payment methods for receiving money
/// - Viewing privacy information
/// - Contacting support
/// - Rating the app
/// - Sharing the app with friends
///
/// All settings are persisted locally using SharedPreferences for privacy.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

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

  /// Display name controller
  final _displayNameController = TextEditingController();

  /// Loading state
  bool _isLoading = true;

  /// Debounce timer for display name saving
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();

    // Load saved payment preferences when screen initializes
    _loadPaymentSettings();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _displayNameController.dispose();
    super.dispose();
  }

  /// Loads saved payment preferences from persistent storage
  Future<void> _loadPaymentSettings() async {
    try {
      // Get selected payment methods
      final savedPayments = await _prefsService.getSelectedPaymentMethods();

      // Load identifiers for each payment method
      final savedIdentifiers = await _prefsService.getAllPaymentIdentifiers();

      // Load display name
      final savedName = await _prefsService.getDisplayName();
      if (savedName != null) {
        _displayNameController.text = savedName;
      }

      // Update state with retrieved values
      if (!mounted) return;
      setState(() {
        _selectedPayments = savedPayments;
        _paymentIdentifiers = savedIdentifiers;
        _isLoading = false;
      });
    } catch (e) {
      // Handle error
      if (!mounted) return;
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

  /// Saves the display name to preferences
  Future<void> _saveDisplayName() async {
    final name = _displayNameController.text.trim();
    if (name.isNotEmpty) {
      await _prefsService.saveDisplayName(name);
    }
  }

  /// Shows the payment method selection and configuration sheet
  void _showPaymentSelection() {
    showPaymentMethodSheet(
      context: context,
      selectedMethods: _selectedPayments,
      identifiers: _paymentIdentifiers,
      onSave: (selectedMethods, identifiers) {
        if (!mounted) return;
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
    try {
      final Uri url = Uri.parse(
        'https://apps.apple.com/us/app/spliq/id6746379502',
      );
      await launchUrl(url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not open App Store'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  /// Opens the device's share sheet to share the app
  Future<void> _shareApp() async {
    const String appStoreLink =
        'https://apps.apple.com/us/app/spliq/id6746379502';

    const String shareText =
        'Check out Billington, the easiest way to split bills with friends! $appStoreLink';

    const String subject = 'Try Billington!';

    // Launch the system share sheet
    SharePlus.instance.share(ShareParams(text: shareText, subject: subject));
  }

  @override
  Widget build(BuildContext context) {
    // Extract theme data for adaptive styling
    final colorScheme = Theme.of(context).colorScheme;
    final screenHeight = MediaQuery.of(context).size.height;

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
                        // Logo stays fixed
                        Center(
                          child: Transform.translate(
                            offset: Offset(0, -screenHeight * 0.06),

                            child: Semantics(
                              label: 'Billington mascot',
                              image: true,
                              child: Image.asset(
                              'assets/images/billy.png',
                              width: 150,
                              height: 150,
                              ),
                            ),
                          ),
                        ),

                        // Everything below the logo shifts up responsively
                        Transform.translate(
                          offset: Offset(0, -screenHeight * 0.10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 8),
                              const Center(
                                child: Text(
                                  'Made by a few friends tired of using\nspreadsheets to split the bill.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 16,
                                    height: 1.4,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 40),

                              // Display name section
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: .15),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Your Name',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Used when creating or joining shared tabs.',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    TextField(
                                      controller: _displayNameController,
                                      textCapitalization:
                                          TextCapitalization.words,
                                      style: TextStyle(
                                        color:
                                            Theme.of(context).brightness ==
                                                    Brightness.dark
                                                ? Colors.white
                                                : Colors.black87,
                                        fontSize: 16,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'Alice',
                                        hintStyle: TextStyle(
                                          color:
                                              Theme.of(context).brightness ==
                                                      Brightness.dark
                                                  ? Colors.white38
                                                  : Colors.black26,
                                        ),
                                        filled: true,
                                        fillColor:
                                            Theme.of(context).brightness ==
                                                    Brightness.dark
                                                ? Colors.white.withValues(
                                                  alpha: .1,
                                                )
                                                : Colors.white,
                                        prefixIcon: Icon(
                                          Icons.person_outline,
                                          color: colorScheme.primary,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: const BorderSide(
                                            color: Color(0xFF627D98),
                                            width: 2,
                                          ),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 14,
                                            ),
                                      ),
                                      onChanged: (_) {
                                        _debounceTimer?.cancel();
                                        _debounceTimer = Timer(const Duration(milliseconds: 500), _saveDisplayName);
                                      },
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 16),

                              // Payment methods section - card with either add button or list of methods
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: .15),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
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

                                    _selectedPayments.isEmpty
                                        ? Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: FilledButton(
                                            onPressed: _showPaymentSelection,
                                            style: FilledButton.styleFrom(
                                              backgroundColor: Colors.white,
                                              foregroundColor:
                                                  colorScheme.primary,
                                              minimumSize:
                                                  const Size.fromHeight(50),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
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
                                                showPaymentMethodSheet(
                                                  context: context,
                                                  selectedMethods:
                                                      _selectedPayments,
                                                  identifiers:
                                                      _paymentIdentifiers,
                                                  onSave: (
                                                    selectedMethods,
                                                    identifiers,
                                                  ) {
                                                    if (!mounted) return;
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
                                                if (!mounted) return;
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
                                                showPaymentMethodSheet(
                                                  context: context,
                                                  selectedMethods:
                                                      _selectedPayments,
                                                  identifiers:
                                                      _paymentIdentifiers,
                                                  onSave: (
                                                    selectedMethods,
                                                    identifiers,
                                                  ) {
                                                    if (!mounted) return;
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
                                            minimumSize: const Size.fromHeight(
                                              50,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
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

                              // Privacy information section
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
                                      children: const [
                                        Icon(
                                          Icons.shield_outlined,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
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
                                    children: const [
                                      Text(
                                        'Your data never leaves your device. Billington is designed with privacy-first principles—zero cloud storage and zero accounts. All information is stored locally and removed completely when you uninstall.',
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

                              // Support options
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: .15),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  children: [
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

                                        canLaunchUrl(emailUri).then((
                                          canLaunch,
                                        ) {
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
                                                    duration: Duration(
                                                      seconds: 2,
                                                    ),
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

                                    ListTile(
                                      title: const Text(
                                        'Rate Us on App Store',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                      subtitle: const Text(
                                        'Love Billington? Let us know!',
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

                              const Center(
                                child: Text(
                                  'Version 1.0.1',
                                  style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 14,
                                  ),
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
}
