import 'package:flutter/material.dart';
import '../models/bill_summary_data.dart';

class ShareOptionsSheet extends StatefulWidget {
  final ShareOptions initialOptions;
  final Function(ShareOptions) onOptionsChanged;
  final VoidCallback onShareTap;

  const ShareOptionsSheet({
    Key? key,
    required this.initialOptions,
    required this.onOptionsChanged,
    required this.onShareTap,
  }) : super(key: key);

  static Future<void> show({
    required BuildContext context,
    required ShareOptions initialOptions,
    required Function(ShareOptions) onOptionsChanged,
    required VoidCallback onShareTap,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => ShareOptionsSheet(
            initialOptions: initialOptions,
            onOptionsChanged: onOptionsChanged,
            onShareTap: onShareTap,
          ),
    );
  }

  @override
  State<ShareOptionsSheet> createState() => _ShareOptionsSheetState();
}

class _ShareOptionsSheetState extends State<ShareOptionsSheet> {
  late ShareOptions _options;

  @override
  void initState() {
    super.initState();
    // Create a copy of the initial options
    _options = ShareOptions(
      includeItemsInShare: widget.initialOptions.includeItemsInShare,
      includePersonItemsInShare:
          widget.initialOptions.includePersonItemsInShare,
      hideBreakdownInShare: widget.initialOptions.hideBreakdownInShare,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Sheet handle for better UX
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            const Center(
              child: Text(
                'Share Options',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),

            const SizedBox(height: 20),

            // Container for all toggles with a subtle background
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  // First toggle - Include all items
                  SwitchListTile(
                    title: const Text('Include all items'),
                    value: _options.includeItemsInShare,
                    onChanged: (value) {
                      setState(() {
                        _options.includeItemsInShare = value;
                      });
                      widget.onOptionsChanged(_options);
                    },
                  ),

                  Divider(height: 1, thickness: 1, color: Colors.grey.shade200),

                  // Second toggle - Show each person's items
                  SwitchListTile(
                    title: const Text('Show each person\'s items'),
                    value: _options.includePersonItemsInShare,
                    onChanged: (value) {
                      setState(() {
                        _options.includePersonItemsInShare = value;
                      });
                      widget.onOptionsChanged(_options);
                    },
                  ),

                  Divider(height: 1, thickness: 1, color: Colors.grey.shade200),

                  // Third toggle - Hide breakdown section
                  SwitchListTile(
                    title: const Text('Hide breakdown details'),
                    value: _options.hideBreakdownInShare,
                    onChanged: (value) {
                      setState(() {
                        _options.hideBreakdownInShare = value;
                      });
                      widget.onOptionsChanged(_options);
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Share button
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
                widget.onShareTap();
              },
              icon: const Icon(Icons.ios_share, size: 20),
              label: const Text('Share Bill Summary'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}