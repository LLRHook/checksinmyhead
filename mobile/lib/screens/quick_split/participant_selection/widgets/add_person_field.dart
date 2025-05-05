import 'package:checks_frontend/screens/quick_split/participant_selection/providers/participants_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// A dual-state widget that expands from a button to a form field
/// for adding participants to the bill splitting flow.
class AddPersonField extends StatefulWidget {
  const AddPersonField({super.key});

  @override
  State<AddPersonField> createState() => _AddPersonFieldState();
}

class _AddPersonFieldState extends State<AddPersonField> {
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isAdding = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// Validates and adds a person to the participants list
  void _addPerson(BuildContext context) {
    if (_formKey.currentState!.validate()) {
      final participantsProvider = Provider.of<ParticipantsProvider>(
        context,
        listen: false,
      );
      participantsProvider.addPerson(_nameController.text);
      _nameController.clear();
      setState(() => _isAdding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Pre-calculate theme-dependent colors
    final textFieldFillColor =
        colorScheme.brightness == Brightness.dark
            ? colorScheme.surfaceContainerHighest
            : Colors.grey.shade100;

    final outlineButtonBgColor = colorScheme.surface;

    final borderSideColor = colorScheme.primary.withValues(
      alpha: colorScheme.brightness == Brightness.dark ? 0.7 : 0.5,
    );

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child:
          _isAdding
              ? _buildForm(context, textFieldFillColor, colorScheme)
              : _buildButton(
                context,
                outlineButtonBgColor,
                colorScheme,
                borderSideColor,
              ),
    );
  }

  /// Builds the expanded form state with text field and add button
  Widget _buildForm(
    BuildContext context,
    Color fillColor,
    ColorScheme colorScheme,
  ) {
    return Form(
      key: _formKey,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextFormField(
              controller: _nameController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: "Enter name",
                filled: true,
                fillColor: fillColor,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colorScheme.primary, width: 2),
                ),
                hintStyle: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              style: TextStyle(color: colorScheme.onSurface),
              onFieldSubmitted: (_) => _addPerson(context),
              validator:
                  (value) =>
                      (value == null || value.trim().isEmpty)
                          ? 'Please enter a name'
                          : null,
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: () => _addPerson(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              elevation: 0,
              padding: const EdgeInsets.all(14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  /// Builds the collapsed button state
  Widget _buildButton(
    BuildContext context,
    Color bgColor,
    ColorScheme colorScheme,
    Color borderColor,
  ) {
    return ElevatedButton.icon(
      onPressed: () => setState(() => _isAdding = true),
      icon: const Icon(Icons.add),
      label: const Text("Add Person"),
      style: ElevatedButton.styleFrom(
        backgroundColor: bgColor,
        foregroundColor: colorScheme.primary,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        side: BorderSide(color: borderColor, width: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
