// Billington: Privacy-first receipt spliting
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

import 'package:flutter/material.dart';

/// LoadingDots
///
/// A customizable animated loading indicator that displays a sequence of pulsing dots.
/// This widget creates a smooth, subtle animation showing three dots that fade in and out
/// in sequence, creating a visual indicator of an ongoing process.
///
/// Features:
/// - Customizable dot color, size, and spacing
/// - Smooth sequential animation that loops continuously
/// - Lightweight and reusable across the application
/// - Visually consistent with modern mobile UX patterns
///
/// This component is designed to be used in any context where a compact,
/// unobtrusive loading indicator is needed, such as within buttons,
/// inline with text, or in smaller UI areas where a full spinner would be too large.
class LoadingDots extends StatefulWidget {
  /// The color of the dots
  final Color color;

  /// The diameter of each dot in logical pixels
  final double size;

  /// The horizontal spacing between dots in logical pixels
  final double spacing;

  const LoadingDots({
    super.key,
    required this.color,
    this.size = 4.0,
    this.spacing = 2.0,
  });

  @override
  State<LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<LoadingDots>
    with TickerProviderStateMixin {
  /// Animation controller for the entire dot sequence
  late AnimationController _controller;

  /// Individual animations for each of the three dots
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();

    // Create a single controller that manages the full animation cycle
    // The 1500ms duration creates a moderate pace that's visually pleasing
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(); // Automatically repeat the animation indefinitely

    // Create three separate animations, one for each dot
    // Each animation is staggered in sequence for a wave-like effect
    _animations = List.generate(3, (index) {
      // Calculate the start and end points for each dot's animation
      // within the overall timeline (0.0 to 1.0)
      // Each dot starts 20% of the way into the previous dot's animation
      final start = index * 0.2;
      final end = start + 0.4; // Each animation takes 40% of the total cycle

      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _controller,
          // The Interval maps the controller's 0-1 value to a specific segment
          // This creates the sequential timing effect
          curve: Interval(start, end, curve: Curves.easeInOut),
        ),
      );
    });
  }

  @override
  void dispose() {
    // Properly dispose of the animation controller to prevent memory leaks
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Calculate the total width based on dot size and spacing
    return SizedBox(
      width: 3 * widget.size + 4 * widget.spacing,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (index) {
          return AnimatedBuilder(
            animation: _animations[index],
            builder: (context, child) {
              // Calculate opacity based on the animation value
              // This creates a smooth fade-in and fade-out effect:
              // - During first 10% (0.0-0.1): Fade in linearly
              // - Middle 80% (0.1-0.9): Stay at full opacity
              // - Final 10% (0.9-1.0): Fade out linearly
              final opacity =
                  _animations[index].value < 0.1
                      ? _animations[index].value *
                          10 // Fade in (0-1 over 0.0-0.1)
                      : _animations[index].value > 0.9
                      ? (1.0 - _animations[index].value) *
                          10 // Fade out (1-0 over 0.9-1.0)
                      : 1.0; // Full opacity in the middle

              // Render the dot as a circular container with animated opacity
              return Container(
                margin: EdgeInsets.symmetric(horizontal: widget.spacing / 2),
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: opacity),
                  shape: BoxShape.circle,
                ),
              );
            },
          );
        }),
      ),
    );
  }
}
