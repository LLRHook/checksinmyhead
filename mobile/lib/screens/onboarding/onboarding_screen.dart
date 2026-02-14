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
import 'package:checks_frontend/screens/settings/payment_method_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _displayNameController = TextEditingController();
  final _prefsService = PreferencesService();

  List<String> _selectedPayments = [];
  Map<String, String> _paymentIdentifiers = {};

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  void _showPaymentSelection() {
    HapticFeedback.selectionClick();
    showPaymentMethodSheet(
      context: context,
      isOnboarding: true,
      selectedMethods: _selectedPayments,
      identifiers: _paymentIdentifiers,
      onSave: (selectedMethods, identifiers) {
        if (!mounted) return;
        setState(() {
          _selectedPayments = selectedMethods;
          _paymentIdentifiers = identifiers;
        });
      },
    );
  }

  Future<void> _completeOnboarding() async {
    HapticFeedback.mediumImpact();

    final name = _displayNameController.text.trim();
    if (name.isNotEmpty) {
      await _prefsService.saveDisplayName(name);
    }

    if (_selectedPayments.isNotEmpty) {
      await _prefsService.saveAllPaymentSettings(
        selectedMethods: _selectedPayments,
        identifiers: _paymentIdentifiers,
      );
    }

    await _prefsService.completeOnboarding();

    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/landing');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.primary,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 48),

              // Logo
              Semantics(
                label: 'Billington app logo',
                image: true,
                child: Image.asset(
                'assets/images/billington.png',
                width: 180,
                height: 180,
                ),
              ),

              const SizedBox(height: 24),

              // Welcome text
              const Text(
                'Welcome to Billington',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Split bills without the hassle',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),

              const SizedBox(height: 40),

              // Step 1: Display name
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
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
                      'This is how others will see you on shared tabs.',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _displayNameController,
                      textCapitalization: TextCapitalization.words,
                      style: TextStyle(
                        color:
                            Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : Colors.black87,
                        fontSize: 16,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Alice',
                        hintStyle: TextStyle(
                          color:
                              Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white38
                                  : Colors.black26,
                        ),
                        filled: true,
                        fillColor:
                            Theme.of(context).brightness == Brightness.dark
                                ? Colors.white.withValues(alpha: 0.1)
                                : Colors.white,
                        prefixIcon: Icon(
                          Icons.person_outline,
                          color: colorScheme.primary,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF627D98),
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Step 2: Payment methods
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Payment Methods',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'How friends can pay you back.',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _showPaymentSelection,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: colorScheme.primary,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _selectedPayments.isEmpty
                            ? 'Add Payment Methods'
                            : 'Edit Payment Methods',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    // Show selected methods as chips
                    if (_selectedPayments.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            _selectedPayments.map((method) {
                              return Chip(
                                label: Text(
                                  method,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                ),
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.15,
                                ),
                                side: BorderSide.none,
                              );
                            }).toList(),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Get Started CTA
              FilledButton(
                onPressed: _completeOnboarding,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: colorScheme.primary,
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Get Started',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),

              const SizedBox(height: 12),

              // Skip option
              TextButton(
                onPressed: _completeOnboarding,
                child: const Text(
                  'Skip for now',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
