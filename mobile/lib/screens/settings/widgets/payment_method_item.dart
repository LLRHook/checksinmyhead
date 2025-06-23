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

import 'package:checks_frontend/config/dialogUtils/dialog_utils.dart';
import 'package:flutter/material.dart';

/// A widget that displays a payment method with edit and delete options
class PaymentMethodItem extends StatelessWidget {
  /// The name of the payment method (e.g., "Venmo")
  final String methodName;

  /// The user identifier for this method (e.g., "@username")
  final String identifier;

  /// Callback when the edit button is pressed
  final VoidCallback onEdit;

  /// Callback when the delete button is pressed
  final VoidCallback onDelete;

  /// Callback when the item is tapped
  final VoidCallback onTap;

  /// Creates a payment method item
  const PaymentMethodItem({
    super.key,
    required this.methodName,
    required this.identifier,
    required this.onEdit,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(methodName),
      background: Container(
        color: Colors.redAccent,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20.0),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      direction: DismissDirection.endToStart,
      // Confirm deletion with native iOS dialog
      confirmDismiss: (direction) async {
        return await AppDialogs.showConfirmationDialog(
          context: context,
          title: 'Delete $methodName?',
          message: 'Are you sure you want to remove this payment method?',
          cancelText: 'Cancel',
          confirmText: 'Delete',
          isDestructive: true,
        );
      },
      // Handle actual deletion when confirmed
      onDismissed: (direction) {
        onDelete();
      },
      child: ListTile(
        title: Text(methodName, style: const TextStyle(color: Colors.white)),
        subtitle: Text(
          identifier,
          style: TextStyle(color: Colors.white.withValues(alpha: .7)),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.more_horiz, color: Colors.white70, size: 20),
          onPressed: () {
            _showOptions(context);
          },
        ),
        onTap: onTap,
      ),
    );
  }

  /// Shows the options menu for this payment method
  void _showOptions(BuildContext context) {
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
                  onEdit();
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
                  Navigator.pop(context);
                  onDelete();
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
