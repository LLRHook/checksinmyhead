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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// BillNameSheet
///
/// A bottom sheet that allows users to edit the name of a bill.
/// This component provides a clean, focused interface for renaming bills
/// with validation, animations, and proper keyboard handling.
///
/// Features:
/// - Pre-filled text field with the current bill name
/// - Validation to prevent empty names
/// - Save button that updates when valid
/// - Haptic feedback for interactions
/// - Proper focus and keyboard handling
class BillNameSheet extends StatefulWidget {
  /// The current name of the bill
  final String currentName;

  /// Callback fired when the user saves a new name
  final Function(String) onNameSaved;

  const BillNameSheet({
    super.key,
    required this.currentName,
    required this.onNameSaved,
  });

  /// Static method to show the sheet with a single call
  ///
  /// This method simplifies the process of displaying the bottom sheet
  /// by handling the showModalBottomSheet call internally.
  static Future<void> show({
    required BuildContext context,
    required String currentName,
    required Function(String) onNameSaved,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allows bottom sheet to resize for keyboard
      backgroundColor: Colors.transparent,
      builder:
          (context) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: BillNameSheet(
              currentName: currentName,
              onNameSaved: onNameSaved,
            ),
          ),
    );
  }

  @override
  State<BillNameSheet> createState() => _BillNameSheetState();
}

class _BillNameSheetState extends State<BillNameSheet> {
  late TextEditingController _nameController;
  bool _isNameValid = true;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    // Initialize controller with current name
    _nameController = TextEditingController(text: widget.currentName);

    // Listen for changes to validate and track modifications
    _nameController.addListener(_validateName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// Validates the name and updates the UI accordingly
  void _validateName() {
    final newName = _nameController.text.trim();

    setState(() {
      // Name is valid if it's not empty
      _isNameValid = newName.isNotEmpty;

      // Track if user has made changes from original name
      _hasChanges = newName != widget.currentName;
    });
  }

  /// Handles the save action when user confirms new name
  void _handleSave() {
    final newName = _nameController.text.trim();

    // Only proceed if name is valid
    if (_isNameValid && newName.isNotEmpty) {
      // Add haptic feedback for confirmation
      HapticFeedback.mediumImpact();

      // Call the parent's callback with new name
      widget.onNameSaved(newName);

      // Close the bottom sheet
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDarkMode = theme.brightness == Brightness.dark;

    // Background colors adapt to theme
    final backgroundColor = isDarkMode ? colorScheme.surface : Colors.white;

    // Error and hint text colors
    final errorColor = colorScheme.error;
    final hintColor = colorScheme.onSurface.withValues(alpha: .6);

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sheet header
              Row(
                children: [
                  Text(
                    'Edit Bill Name',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  // Close button
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: colorScheme.onSurface.withValues(alpha: .7),
                    ),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Name input field
              TextField(
                controller: _nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Bill Name',
                  hintText: 'Enter a name for this bill',
                  hintStyle: TextStyle(color: hintColor),
                  errorText: !_isNameValid ? 'Name cannot be empty' : null,
                  errorStyle: TextStyle(color: errorColor),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor:
                      isDarkMode
                          ? colorScheme.surface.withValues(alpha: .8)
                          : Colors.grey[50],
                ),
                onSubmitted: (_) {
                  if (_isNameValid) {
                    _handleSave();
                  }
                },
              ),

              const SizedBox(height: 24),

              // Save button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isNameValid && _hasChanges ? _handleSave : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    disabledBackgroundColor: colorScheme.primary.withValues(
                      alpha: 0.3,
                    ),
                  ),
                  child: const Text(
                    'Save',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
