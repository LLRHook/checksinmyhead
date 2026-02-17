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

import 'package:checks_frontend/screens/quick_split/item_assignment/utils/animation_utils.dart';
import 'package:checks_frontend/screens/quick_split/item_assignment/utils/color_utils.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import 'package:checks_frontend/models/person.dart';

/// A reusable participant avatar component that displays user information with
/// various visual states for assignment, selection, and birthday status.
///
/// This widget creates a consistent, accessible representation of participants
/// across the app with features including:
/// - Customized avatar appearance with user's initial or birthday cake icon
/// - Visual indicators for assignment and selection states
/// - Animated effects including pulse animations and birthday celebrations
/// - Color adaptations for both light and dark themes to ensure readability
/// - Haptic feedback on interactions for enhanced user experience
/// - Proper overflow handling for names of different lengths
///
/// The avatar displays the person's first initial by default, but shows a
/// cake icon with animation effects when the person is marked as the birthday person.
class ParticipantAvatar extends StatelessWidget {
  /// The person data to display in this avatar
  final Person person;

  /// Whether this person is currently assigned to an item
  final bool isAssigned;

  /// Whether this person is currently selected in multi-select mode
  final bool isSelected;

  /// Whether this person is celebrating their birthday (and exempt from payment)
  final bool isBirthdayPerson;

  /// Callback when the avatar is tapped
  final VoidCallback onTap;

  /// Callback when the avatar is long-pressed
  final VoidCallback? onLongPress;

  final double? assignedPercentage;

  /// Creates a participant avatar with the specified states and callbacks
  ///
  /// All parameters are required to ensure consistent appearance and behavior across the app.
  const ParticipantAvatar({
    super.key,
    required this.person,
    required this.isAssigned,
    required this.isSelected,
    required this.isBirthdayPerson,
    required this.onTap,
    required this.onLongPress,
    this.assignedPercentage,
  });

  @override
  Widget build(BuildContext context) {
    // Get theme information for adaptive styling
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    // Special color for the birthday person - adjusted for theme brightness
    // Use lighter purple in dark mode for better visibility
    final birthdayColor =
        brightness == Brightness.dark
            ? const Color(
              0xFFCE93D8,
            ) // Extra light purple for dark mode (Purple 200)
            : const Color(0xFF8E24AA); // Purple 600 for light mode

    // Calculate the appropriate text color for the name based on state and theme
    final nameColor = _getNameColor(context, birthdayColor);

    // Border color for the checkmark - use neutral background color based on theme
    final checkmarkBorderColor =
        brightness == Brightness.dark ? colorScheme.surface : Colors.white;

    // Check if we need to show percentage info
    final hasCustomSplit =
        assignedPercentage != null &&
        assignedPercentage != 100.0 &&
        assignedPercentage! > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: SizedBox(
          width: 70,
          height: 90, // Increased height to accommodate percentage text
          // Use a flexible layout with proper constraints to prevent overflow
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize:
                MainAxisSize.min, // Minimize column size to prevent overflow
            children: [
              // Avatar with selection indication - explicit height for consistency
              SizedBox(
                height: 46, // Fixed height contains all avatar elements
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Circular progress indicator for custom split percentages
                    if (hasCustomSplit)
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Background circle
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: person.color.withValues(alpha: 0.15),
                                  width: 2.5,
                                ),
                              ),
                            ),
                            // Progress arc
                            SizedBox(
                              width: 48,
                              height: 48,
                              child: CustomPaint(
                                painter: ArcPainter(
                                  color: person.color,
                                  percentage: assignedPercentage!,
                                  strokeWidth: 2.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Outer selection ring - shows when selected or assigned (but not custom split)
                    if (!hasCustomSplit)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: (isSelected || isAssigned) ? 46 : 42,
                        height: (isSelected || isAssigned) ? 46 : 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.transparent,
                          border: Border.all(
                            color:
                                isSelected
                                    ? _getSelectionColor(
                                      person.color,
                                      brightness,
                                    )
                                    : isAssigned
                                    ? person.color
                                    : Colors.transparent,
                            width:
                                isSelected
                                    ? 3 // Thicker border for selected state
                                    : isAssigned
                                    ? 2 // Medium border for assigned state
                                    : 0, // No border for default state
                          ),
                        ),
                      ),

                    // Animated pulse effect for selected avatars (except birthday person)
                    if (isSelected && !isBirthdayPerson)
                      SizedBox(
                        width: 54,
                        height: 54,
                        child: CustomPaint(
                          painter: PulsePainter(color: person.color),
                        ),
                      ),

                    // Main avatar circle with person's color and initial
                    Container(
                      margin: const EdgeInsets.all(4),
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isBirthdayPerson ? birthdayColor : person.color,
                        boxShadow: [
                          BoxShadow(
                            color:
                                isBirthdayPerson
                                    ? birthdayColor.withValues(alpha: .3)
                                    : person.color.withValues(alpha: .3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child:
                            isBirthdayPerson
                                ? const Icon(
                                  Icons.cake,
                                  color: Colors.white,
                                  size: 18,
                                )
                                : Text(
                                  person.name[0].toUpperCase(), // First initial
                                  style: TextStyle(
                                    color: ColorUtils.getContrastiveTextColor(
                                      person.color,
                                    ),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                      ),
                    ),

                    // Animated cake icon for birthday person with special effects
                    if (isBirthdayPerson)
                      _buildShakingCakeIcon(birthdayColor, brightness),

                    // Checkmark indicator for selected or assigned state
                    if (isSelected || isAssigned)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: person.color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: checkmarkBorderColor,
                              width: 2,
                            ),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.check,
                              size: 10,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Small gap between avatar and name
              const SizedBox(height: 2),

              // Name and percentage labels stacked vertically
              Column(
                children: [
                  // Name label with explicit constraints and overflow handling
                  SizedBox(
                    height: 16,
                    child: Text(
                      person.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            isSelected || isAssigned || isBirthdayPerson
                                ? FontWeight
                                    .w600 // Bold for active states
                                : FontWeight
                                    .w500, // Medium weight for default state
                        color: nameColor,
                      ),
                    ),
                  ),

                  // Percentage label if custom split
                  if (hasCustomSplit)
                    Text(
                      '${assignedPercentage!.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: person.color,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Calculates the appropriate text color for the name label based on state and theme
  ///
  /// Enhances visibility in dark mode with adaptive lightening for different colors.
  /// Returns a color that ensures proper contrast against the background.
  Color _getNameColor(BuildContext context, Color birthdayColor) {
    final brightness = Theme.of(context).brightness;

    // Special handling for birthday person
    if (isBirthdayPerson) {
      // Make birthday color extra bright in dark mode for visibility
      return brightness == Brightness.dark
          ? ColorUtils.getLightenedColor(
            birthdayColor,
            0.3,
          ) // Significantly lighter
          : birthdayColor;
    }

    // For selected or assigned states, use the person's color with adjustments
    if (isSelected || isAssigned) {
      // Check if color is in the purple family (harder to see in dark mode)
      bool isPurplish = ColorUtils.isPurplish(person.color);

      if (brightness == Brightness.dark) {
        // Apply extra lightening for purplish colors in dark mode
        if (isPurplish) {
          return ColorUtils.getLightenedColor(
            person.color,
            0.5,
          ); // 50% lighter for purple
        } else {
          return ColorUtils.getLightenedColor(
            person.color,
            0.3,
          ); // 30% lighter for other colors
        }
      }
      return person.color; // Use original color in light mode
    }

    // Default color for inactive state - lighter in dark mode
    return brightness == Brightness.dark
        ? Theme.of(context).colorScheme.onSurface.withValues(
          alpha: 0.9,
        ) // Brighter default text in dark mode
        : Colors.grey.shade700; // Darker gray in light mode
  }

  /// Calculates the appropriate color for the selection ring based on theme
  ///
  /// Enhances visibility in dark mode with adaptive lightening for different colors.
  /// Returns a color that ensures the selection indicator is clearly visible.
  Color _getSelectionColor(Color color, Brightness brightness) {
    // Check if color is in the purple family (harder to see in dark mode)
    bool isPurplish = ColorUtils.isPurplish(color);

    if (brightness == Brightness.dark) {
      // Apply extra lightening for purplish colors in dark mode
      if (isPurplish) {
        return ColorUtils.getLightenedColor(
          color,
          0.6,
        ); // 60% lighter for purple
      } else {
        return ColorUtils.getLightenedColor(
          color,
          0.4,
        ); // 40% lighter for other colors
      }
    }
    // Slightly darker color for light mode to enhance contrast
    return ColorUtils.getDarkenedColor(color, 0.1);
  }

  /// Builds an animated cake icon with rotation, scaling, and glowing effects
  ///
  /// Creates a celebratory animation for the birthday person's avatar
  /// with multiple overlapping effects for visual interest.
  Widget _buildShakingCakeIcon(Color backgroundColor, Brightness brightness) {
    // Adjust cake icon color for dark mode to ensure visibility
    final iconColor =
        brightness == Brightness.dark
            ? Colors.black.withValues(
              alpha: 0.9,
            ) // Dark icon for better contrast in dark mode
            : Colors.white; // White icon for light mode

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 2000),
      curve: Curves.linear,
      onEnd: () {
        // Immediately restart the animation when it completes to make it seamless
        Future.microtask(() {});
      },
      builder: (context, value, child) {
        // Calculate rotation using a sin wave for natural swaying motion
        final rotation =
            sin(value * pi * 2) * 0.08; // Gentle rotation of ±0.08 radians

        // Calculate scale using a different frequency sin wave for bouncing effect
        final scale =
            1.0 + sin(value * pi * 4 + 0.3) * 0.1; // Scale between 0.9-1.1

        // Calculate glow intensity with a third sin wave for pulsing effect
        final glowIntensity =
            0.3 + sin(value * pi * 3) * 0.1; // Glow between 0.2-0.4

        return Stack(
          alignment: Alignment.center,
          children: [
            // Glowing background effect with pulsing intensity
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    backgroundColor,
                    backgroundColor.withValues(alpha: .5 * glowIntensity),
                    backgroundColor.withValues(alpha: .0),
                  ],
                  stops: const [0.3, 0.6, 1.0],
                ),
              ),
            ),

            // Rotating and scaling cake icon for lively animation
            Transform.scale(
              scale: scale,
              child: Transform.rotate(
                angle: rotation,
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: backgroundColor,
                  child: Icon(Icons.cake, color: iconColor, size: 16),
                ),
              ),
            ),

            // Sparkle effect that moves independently from the cake
            Positioned(
              top: 4 + sin(value * pi * 5) * 4, // Moving vertically
              right: 4 + cos(value * pi * 5) * 4, // Moving horizontally
              child: Transform.rotate(
                angle: value * pi * 4, // Rotating sparkle
                child: Icon(
                  Icons.star,
                  // Opacity also pulses for twinkling effect
                  color: iconColor.withValues(
                    alpha: .7 + sin(value * pi * 6) * 0.3,
                  ),
                  size: 6,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
