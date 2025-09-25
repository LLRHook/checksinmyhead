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

/// LoadingBillsState
///
/// A loading indicator widget that displays animated bill card placeholders
/// while bill data is being fetched. This component provides visual feedback
/// to users during the loading process with a subtle pulsing animation.
///
/// Features:
/// - Animated shimmer effect with theme-aware colors
/// - Placeholder cards that match the layout of actual bill cards
/// - Smooth opacity animation to indicate loading state
/// - Responsive layout that adapts to different screen sizes
///
/// This component creates a seamless loading experience that maintains
/// the same visual structure as the actual content, reducing perceived
/// loading time and layout shifts when the real data arrives.
class LoadingBillsState extends StatefulWidget {
  const LoadingBillsState({super.key});

  @override
  State<LoadingBillsState> createState() => _LoadingBillsStateState();
}

class _LoadingBillsStateState extends State<LoadingBillsState>
    with SingleTickerProviderStateMixin {
  // Animation controller for the loading effect
  late AnimationController _loadingAnimationController;

  // Animation for the pulsing opacity effect
  late Animation<double> _loadingAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize the animation controller with a moderate duration
    // and set it to repeat with reverse for a breathing effect
    _loadingAnimationController = AnimationController(
      vsync: this, // Use this widget as the vsync source
      duration: const Duration(milliseconds: 1500), // 1.5 seconds per cycle
    )..repeat(reverse: true); // Automatically repeat the animation in reverse

    // Create a tween animation that changes opacity from 60% to 100%
    // This creates a subtle breathing effect that indicates loading
    _loadingAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _loadingAnimationController,
        curve: Curves.easeInOut, // Smooth acceleration and deceleration
      ),
    );
  }

  @override
  void dispose() {
    // Clean up the animation controller when the widget is removed
    // This prevents memory leaks and unnecessary processing
    _loadingAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Extract theme information for adaptive styling
    final brightness = Theme.of(context).brightness;

    // Define shimmer colors based on the current theme
    // Darker grays for dark mode, lighter grays for light mode
    final shimmerBaseColor =
        brightness == Brightness.dark ? Colors.grey[800]! : Colors.grey[300]!;
    final shimmerHighlightColor =
        brightness == Brightness.dark ? Colors.grey[700]! : Colors.grey[100]!;

    return Padding(
      padding: const EdgeInsets.only(top: 20.0),
      child: Column(
        // Generate 3 placeholder bill cards
        children: List.generate(3, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0), // Space between cards
            child: AnimatedBuilder(
              // Attach the animated builder to our loading animation
              animation: _loadingAnimation,
              builder: (context, child) {
                return Opacity(
                  // Apply the animated opacity value
                  opacity: _loadingAnimation.value,
                  child: Container(
                    height: 100, // Fixed height matching real bill cards
                    decoration: BoxDecoration(
                      color: shimmerBaseColor, // Background color of the card
                      borderRadius: BorderRadius.circular(
                        16,
                      ), // Rounded corners
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 16), // Left padding
                        // Bill icon placeholder (circular)
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: shimmerHighlightColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 16), // Spacing
                        // Bill details placeholder (two horizontal bars)
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Title placeholder (shorter, thicker bar)
                              Container(
                                height: 18,
                                width: 120,
                                decoration: BoxDecoration(
                                  color: shimmerHighlightColor,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(height: 12), // Vertical spacing
                              // Subtitle placeholder (longer, thinner bar)
                              Container(
                                height: 14,
                                width: 180,
                                decoration: BoxDecoration(
                                  color: shimmerHighlightColor,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16), // Spacing
                        // Price placeholder (right-aligned bar)
                        Container(
                          height: 22,
                          width: 70,
                          decoration: BoxDecoration(
                            color: shimmerHighlightColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 16), // Right padding
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        }),
      ),
    );
  }
}
