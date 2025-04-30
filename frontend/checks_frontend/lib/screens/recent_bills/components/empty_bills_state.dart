// lib/screens/recent_bills/components/empty_bills_state.dart
import 'package:flutter/material.dart';

class EmptyBillsState extends StatelessWidget {
  const EmptyBillsState({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Clean icon without background circle
          Icon(
            Icons.receipt_long_outlined,
            size: 72,
            color: colorScheme.primary.withOpacity(0.8),
          ),
          const SizedBox(height: 24),
          Text(
            'No bills yet!',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          // Shorter, snappier message
          Text(
            'Tap "Quick Split" to get started',
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }
}
