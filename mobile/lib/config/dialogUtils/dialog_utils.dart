import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Dialog utility class for creating consistent iOS-style dialogs
class AppDialogs {
  static void showError(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.cloud_off, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: Colors.orange.shade700,
      ),
    );
  }

  /// Creates a consistent iOS-styled alert dialog with better native appearance
  ///
  /// This method standardizes the dialog appearance across the app by:
  /// - Using proper CupertinoDialogAction widgets for iOS-native button styling
  /// - Maintaining consistent spacing and font sizes
  /// - Supporting both destructive and non-destructive actions
  /// - Automatically adapting to light/dark mode
  ///
  /// Parameters:
  /// - context: BuildContext for theming
  /// - title: Dialog title text
  /// - message: Dialog content text
  /// - cancelText: Text for the cancel button
  /// - confirmText: Text for the confirm button
  /// - isDestructive: Whether the confirm action is destructive (will use red color)
  /// - icon: Optional icon to show before the title
  static Future<bool?> showConfirmationDialog({
    required BuildContext context,
    required String title,
    required String message,
    String cancelText = 'Cancel',
    String confirmText = 'Confirm',
    bool isDestructive = false,
    IconData? icon,
  }) async {
    return showCupertinoDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title:
              icon != null
                  ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icon,
                        color:
                            isDestructive
                                ? CupertinoColors.destructiveRed
                                : null,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Flexible(child: Text(title)),
                    ],
                  )
                  : Text(title),
          content: Text(
            message,
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
          actions: <CupertinoDialogAction>[
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(false),
              isDefaultAction: true,
              child: Text(cancelText),
            ),
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(true),
              isDestructiveAction: isDestructive,
              child: Text(confirmText),
            ),
          ],
        );
      },
    );
  }
}
