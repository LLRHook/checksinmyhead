import 'package:flutter/material.dart';

class SectionCard extends StatelessWidget {
  final String title;
  final String? subTitle;
  final IconData icon;
  final List<Widget> children;

  const SectionCard({
    Key? key,
    required this.title,
    this.subTitle,
    required this.icon,
    required this.children,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Premium section header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: colorScheme.primary, size: 18),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          // Optional subtitle
          if (subTitle != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 38),
              child: Text(
                subTitle!,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Section content
          ...children,
        ],
      ),
    );
  }
}