import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/participants_provider.dart';

class AddPersonField extends StatefulWidget {
  const AddPersonField({Key? key}) : super(key: key);

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

  void _addPerson(BuildContext context) {
    if (_formKey.currentState!.validate()) {
      final participantsProvider = Provider.of<ParticipantsProvider>(
        context,
        listen: false,
      );
      participantsProvider.addPerson(_nameController.text);
      _nameController.clear();
      setState(() {
        _isAdding = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Theme-aware colors
    final textFieldFillColor =
        colorScheme.brightness == Brightness.dark
            ? colorScheme.surfaceContainerHighest
            : Colors.grey.shade100;

    final outlineButtonBgColor =
        colorScheme.brightness == Brightness.dark
            ? colorScheme.surface
            : colorScheme.surface;

    final borderSideColor =
        colorScheme.brightness == Brightness.dark
            ? colorScheme.primary.withOpacity(0.7)
            : colorScheme.primary.withOpacity(0.5);

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child:
          _isAdding
              ? Form(
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
                          fillColor: textFieldFillColor,
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
                            borderSide: BorderSide(
                              color: colorScheme.primary,
                              width: 2,
                            ),
                          ),
                          // Add style for the hint text
                          hintStyle: TextStyle(
                            color: colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                        style: TextStyle(
                          color:
                              colorScheme
                                  .onSurface, // Ensure text color respects theme
                        ),
                        onFieldSubmitted: (_) {
                          _addPerson(context);
                        },
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a name';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
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
                  ],
                ),
              )
              : ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _isAdding = true;
                  });
                },
                icon: const Icon(Icons.add),
                label: const Text("Add Person"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: outlineButtonBgColor,
                  foregroundColor: colorScheme.primary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 16,
                  ),
                  side: BorderSide(color: borderSideColor, width: 1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
    );
  }
}
