import 'package:flutter/material.dart';

/// A visually appealing empty state widget displaying when no participants are added
/// Features a gradient circle with people icon and instructional text
class EmptyState extends StatelessWidget {
  const EmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Pre-calculate theme-aware colors
    final containerGradientColors =
        isDark
            ? [
              colorScheme.surface.withValues(alpha: 0.5),
              colorScheme.surfaceContainerHighest,
            ]
            : [Colors.grey.shade50, Colors.grey.shade100];

    final innerCircleColor =
        isDark ? colorScheme.surfaceContainerHighest : Colors.grey.shade50;

    final innerCircleBorderColor =
        isDark
            ? colorScheme.onSurface.withValues(alpha: 0.1)
            : Colors.grey.shade200;

    final shadowColor =
        isDark ? Colors.black.withValues(alpha: 0.3) : Colors.grey.shade200;

    final labelColor =
        isDark
            ? colorScheme.onSurface.withValues(alpha: 0.7)
            : Colors.grey.shade600;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildIllustration(
            colorScheme,
            containerGradientColors,
            innerCircleColor,
            innerCircleBorderColor,
            shadowColor,
          ),
          const SizedBox(height: 24),
          _buildHeadingText(colorScheme),
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

  /// Creates the main circular illustration with people icon and add button
  Widget _buildIllustration(
    ColorScheme colorScheme,
    List<Color> gradientColors,
    Color innerCircleColor,
    Color borderColor,
    Color shadowColor,
  ) {
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
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
            // Inner circle with border
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: innerCircleColor,
                shape: BoxShape.circle,
                border: Border.all(color: borderColor, width: 2),
              ),
            ),
            // People icon with gradient effect
            ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback:
                  (Rect bounds) => LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      colorScheme.primary.withValues(alpha: 0.6),
                      colorScheme.primary.withValues(alpha: 0.3),
                    ],
                  ).createShader(bounds),
              child: Icon(
                Icons.group_outlined,
                size: 64,
                color: colorScheme.primary,
              ),
            ),
            // Add button overlay
            Positioned(
              bottom: 10,
              right: 10,
              child: _buildAddButton(colorScheme),
            ),
          ],
        ),
      ),
    );
  }

  /// Creates the floating add button with shadow
  Widget _buildAddButton(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colorScheme.primary,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.4),
            blurRadius: 8,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(Icons.add, size: 20, color: colorScheme.onPrimary),
    );
  }

  /// Creates the gradient title text
  Widget _buildHeadingText(ColorScheme colorScheme) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback:
          (Rect bounds) => LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              colorScheme.primary.withValues(alpha: .9),
              colorScheme.primary.withValues(alpha: .7),
            ],
          ).createShader(bounds),
      child: const Text(
        "Your Move",
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
      ),
    );
  }
}
