import 'package:flutter/material.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    // Theme-aware colors
    final containerGradientColors =
        brightness == Brightness.dark
            ? [
              colorScheme.surface.withOpacity(0.5),
              colorScheme.surfaceContainerHighest,
            ]
            : [Colors.grey.shade50, Colors.grey.shade100];

    final innerCircleColor =
        brightness == Brightness.dark
            ? colorScheme.surfaceContainerHighest
            : Colors.grey.shade50;

    final innerCircleBorderColor =
        brightness == Brightness.dark
            ? colorScheme.onSurface.withOpacity(0.1)
            : Colors.grey.shade200;

    final shadowColor =
        brightness == Brightness.dark
            ? Colors.black.withOpacity(0.3)
            : Colors.grey.shade200;

    final labelColor =
        brightness == Brightness.dark
            ? colorScheme.onSurface.withOpacity(0.7)
            : Colors.grey.shade600;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Premium illustration container
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: containerGradientColors,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: shadowColor, blurRadius: 15, spreadRadius: 5),
              ],
            ),
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Background soft circle
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      color: innerCircleColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: innerCircleBorderColor,
                        width: 2,
                      ),
                    ),
                  ),
                  // People icon with gradient
                  ShaderMask(
                    blendMode: BlendMode.srcIn,
                    shaderCallback:
                        (Rect bounds) => LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            colorScheme.primary.withOpacity(0.6),
                            colorScheme.primary.withOpacity(0.3),
                          ],
                        ).createShader(bounds),
                    child: Icon(
                      Icons.group_outlined,
                      size: 64,
                      color: colorScheme.primary,
                    ),
                  ),
                  // Small add icon with circle background
                  Positioned(
                    bottom: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withOpacity(0.4),
                            blurRadius: 8,
                            spreadRadius: 0,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.add,
                        size: 20,
                        color: colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Premium text with gradient - Checkmate pun
          ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback:
                (Rect bounds) => LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    colorScheme.primary.withOpacity(0.9),
                    colorScheme.primary.withOpacity(0.7),
                  ],
                ).createShader(bounds),
            child: const Text(
              "Your Move",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Add someone to split the bill",
            style: TextStyle(
              fontSize: 14,
              color: labelColor,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
