import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BottomBar extends StatelessWidget {
  final VoidCallback onShareTap;
  final VoidCallback? onReuseTap;

  const BottomBar({Key? key, required this.onShareTap, this.onReuseTap})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Share button
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onShareTap,
                icon: const Icon(Icons.ios_share, size: 18),
                label: const Text('Share'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 12),

            // Reuse button
            Expanded(
              child: FilledButton.icon(
                onPressed:
                    onReuseTap ??
                    () {
                      HapticFeedback.mediumImpact();
                      // Default behavior if no onReuseTap provided
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text(
                            'Reuse bill functionality coming soon',
                          ),
                          behavior: SnackBarBehavior.floating,
                          width: MediaQuery.of(context).size.width * 0.9,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      );
                    },
                icon: const Icon(Icons.refresh_outlined, size: 18),
                label: const Text('Reuse'),
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
