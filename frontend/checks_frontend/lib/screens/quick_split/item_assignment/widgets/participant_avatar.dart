import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import '/models/person.dart';

/// A reusable participant avatar that can be used consistently across the app
class ParticipantAvatar extends StatelessWidget {
  final Person person;
  final bool isAssigned;
  final bool isSelected;
  final bool isBirthdayPerson;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const ParticipantAvatar({
    Key? key,
    required this.person,
    required this.isAssigned,
    required this.isSelected,
    required this.isBirthdayPerson,
    required this.onTap,
    required this.onLongPress,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Birthday color
    final birthdayColor = const Color(0xFF8E24AA); // Purple 600

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          width: 70,
          height: 70,
          // Use a more flexible layout with proper constraints
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min, // Add this to prevent overflow
            children: [
              // Avatar with selection indication - give it more space
              SizedBox(
                height: 46, // Explicit height to contain the avatar
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Selection ring
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
                                  ? _getDarkenedColor(person.color, 0.1)
                                  : isAssigned
                                  ? person.color
                                  : Colors.transparent,
                          width:
                              isSelected
                                  ? 3
                                  : isAssigned
                                  ? 2
                                  : 0,
                        ),
                      ),
                    ),

                    // Pulse effect for selected state
                    if (isSelected && !isBirthdayPerson)
                      SizedBox(
                        width: 54,
                        height: 54,
                        child: CustomPaint(
                          painter: PulsePainter(color: person.color),
                        ),
                      ),

                    // Avatar circle
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
                                    ? birthdayColor.withOpacity(0.3)
                                    : person.color.withOpacity(0.3),
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
                                  person.name[0].toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                      ),
                    ),

                    // Use the animated cake icon for birthday person
                    if (isBirthdayPerson) _buildShakingCakeIcon(birthdayColor),

                    // Standardized colored checkmark for both selection and assignment
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
                            border: Border.all(color: Colors.white, width: 2),
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

              // Reduce space between avatar and name
              const SizedBox(height: 2), // Reduced from 4 to 2
              // Name - with explicit constraints
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
                            ? FontWeight.w600
                            : FontWeight.w500,
                    color:
                        isBirthdayPerson
                            ? birthdayColor
                            : isSelected || isAssigned
                            ? person.color
                            : Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // The enhanced cake animation - extracted to a shared component
  Widget _buildShakingCakeIcon(Color backgroundColor) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 2000),
      curve: Curves.linear,
      onEnd: () {
        // Immediately restart the animation when it completes to make it seamless
        Future.microtask(() {});
      },
      builder: (context, value, child) {
        // Calculate rotation using a sin wave for more natural motion
        final rotation = sin(value * pi * 2) * 0.08;

        // Calculate scale using a different frequency for variety
        final scale = 1.0 + sin(value * pi * 4 + 0.3) * 0.1;

        // Calculate glow intensity to add subtle pulsing
        final glowIntensity = 0.3 + sin(value * pi * 3) * 0.1;

        return Stack(
          alignment: Alignment.center,
          children: [
            // Enhanced glowing background effect with pulsing
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    backgroundColor,
                    backgroundColor.withOpacity(0.5 * glowIntensity),
                    backgroundColor.withOpacity(0.0),
                  ],
                  stops: const [0.3, 0.6, 1.0],
                ),
              ),
            ),

            // Rotating and scaling cake icon with more fluid animation
            Transform.scale(
              scale: scale,
              child: Transform.rotate(
                angle: rotation,
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: backgroundColor,
                  child: const Icon(Icons.cake, color: Colors.white, size: 16),
                ),
              ),
            ),

            // Add a subtle sparkle effect
            Positioned(
              top: 4 + sin(value * pi * 5) * 4,
              right: 4 + cos(value * pi * 5) * 4,
              child: Transform.rotate(
                angle: value * pi * 4,
                child: Icon(
                  Icons.star,
                  color: Colors.white.withOpacity(
                    0.7 + sin(value * pi * 6) * 0.3,
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

  // Helper to get a darkened version of a color
  Color _getDarkenedColor(Color color, double factor) {
    return Color.fromARGB(
      color.alpha,
      (color.red * (1 - factor)).round(),
      (color.green * (1 - factor)).round(),
      (color.blue * (1 - factor)).round(),
    );
  }
}

// Extract PulsePainter to a shared utility file
class PulsePainter extends CustomPainter {
  final Color color;

  PulsePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // Create multiple pulse waves with different opacities and sizes
    for (int i = 0; i < 3; i++) {
      final animationPhase =
          (DateTime.now().millisecondsSinceEpoch / 1500 + i * 0.33) % 1.0;

      // Adjust the pulse radius based on the animation phase
      final pulseRadius = maxRadius * animationPhase;

      // Make the pulse fade out as it expands
      final opacity = (1.0 - animationPhase) * 0.4;

      final paint =
          Paint()
            ..color = color.withOpacity(opacity)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0;

      canvas.drawCircle(center, pulseRadius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true; // Always repaint to animate
  }
}
