import 'package:flutter/material.dart';
import 'dart:math';
import '/models/person.dart';

class ParticipantSelector extends StatelessWidget {
  final List<Person> participants;
  final Person? selectedPerson;
  final Person? birthdayPerson;
  final Map<Person, double> personFinalShares;
  final Function(Person) onPersonSelected;
  final Function(Person) onBirthdayToggle;
  final double Function(Person) getPersonBillPercentage;

  const ParticipantSelector({
    super.key,
    required this.participants,
    required this.selectedPerson,
    required this.birthdayPerson,
    required this.personFinalShares,
    required this.onPersonSelected,
    required this.onBirthdayToggle,
    required this.getPersonBillPercentage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Instruction text with improved visibility
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
            child: Row(
              mainAxisAlignment:
                  MainAxisAlignment.center, // Center the row contents
              children: [
                Icon(Icons.info_outline, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  'Tap to assign • Long-press to set birthday person',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Participant avatars
          SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: participants.length,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              itemBuilder: (context, index) {
                final person = participants[index];
                return _buildParticipantChip(
                  person: person,
                  isSelected: selectedPerson == person,
                  isBirthdayPerson: birthdayPerson == person,
                  share: personFinalShares[person] ?? 0.0,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Replace the _buildShakingCakeIcon method in ParticipantSelector with this enhanced version:

  Widget _buildShakingCakeIcon(Color backgroundColor) {
    return TweenAnimationBuilder<double>(
      // Use a continuous animation value from 0 to 1
      tween: Tween<double>(begin: 0.0, end: 1.0),
      // Longer duration for more fluid motion
      duration: const Duration(milliseconds: 2000),
      // Use a continuous curve for smoother animation
      curve: Curves.linear,
      onEnd: () {
        // Immediately restart the animation when it completes to make it seamless
        Future.microtask(() {});
      },
      builder: (context, value, child) {
        // Calculate rotation using a sin wave for more natural motion
        // The sin function creates a smooth wave pattern that looks more organic
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

  Widget _buildParticipantChip({
    required Person person,
    required bool isSelected,
    required bool isBirthdayPerson,
    required double share,
  }) {
    // Birthday color - changed to a more distinctive purple shade
    // that's less likely to clash with person colors
    final birthdayColor = const Color(0xFF8E24AA); // Purple 600

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        onTap: isBirthdayPerson ? null : () => onPersonSelected(person),
        onLongPress: () => onBirthdayToggle(person),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutQuint,
          height: 56,
          constraints: const BoxConstraints(maxWidth: 110),
          decoration: BoxDecoration(
            color:
                isBirthdayPerson
                    ? birthdayColor.withOpacity(0.15)
                    : isSelected
                    ? person.color.withOpacity(0.15)
                    : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(isSelected ? 14 : 12),
            border: Border.all(
              color:
                  isBirthdayPerson
                      ? birthdayColor
                      : isSelected
                      ? person.color
                      : Colors.grey.shade300,
              width: (isBirthdayPerson || isSelected) ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color:
                    isBirthdayPerson
                        ? birthdayColor.withOpacity(0.35)
                        : isSelected
                        ? person.color.withOpacity(0.35)
                        : Colors.black.withOpacity(0.02),
                blurRadius: (isBirthdayPerson || isSelected) ? 10 : 4,
                spreadRadius: (isBirthdayPerson || isSelected) ? 1 : 0,
                offset:
                    (isBirthdayPerson || isSelected)
                        ? const Offset(0, 3)
                        : const Offset(0, 1),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Avatar with animations
                Stack(
                  children: [
                    // Selection pulse animation
                    if (isSelected && !isBirthdayPerson)
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 1200),
                        curve: Curves.easeInOut,
                        builder: (context, value, child) {
                          return RepaintBoundary(
                            child: CustomPaint(
                              size: const Size(36, 36),
                              painter: PulsePainter(
                                color: person.color.withOpacity(0.2),
                                progress: value,
                              ),
                            ),
                          );
                        },
                      ),

                    // Avatar with scale animation
                    AnimatedScale(
                      scale: (isBirthdayPerson || isSelected) ? 1.1 : 1.0,
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.elasticOut,
                      child:
                          isBirthdayPerson
                              ? _buildShakingCakeIcon(birthdayColor)
                              : CircleAvatar(
                                radius: 16,
                                backgroundColor:
                                    isSelected
                                        ? person.color
                                        : person.color.withOpacity(0.9),
                                child: AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 250),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: isSelected ? 14 : 12,
                                  ),
                                  child: Text(person.name[0].toUpperCase()),
                                ),
                              ),
                    ),
                  ],
                ),

                const SizedBox(width: 6),

                // Name and amount with animations
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 250),
                        style: TextStyle(
                          fontSize: (isBirthdayPerson || isSelected) ? 13 : 12,
                          fontWeight:
                              (isBirthdayPerson || isSelected)
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                          color:
                              isBirthdayPerson
                                  ? _getDarkenedColor(birthdayColor, 0.3)
                                  : isSelected
                                  ? _getDarkenedColor(person.color, 0.3)
                                  : Colors.grey.shade800,
                        ),
                        child: Text(
                          person.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      // Share amount or birthday text
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (
                          Widget child,
                          Animation<double> animation,
                        ) {
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, -0.5),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                        child:
                            isBirthdayPerson
                                ? Row(
                                  key: const ValueKey('birthday'),
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.cake,
                                      size: 10,
                                      color: Colors.pink,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      '\$0.00',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                        color: _getDarkenedColor(
                                          birthdayColor,
                                          0.3,
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                                : Text(
                                  '\$${share.toStringAsFixed(2)}',
                                  key: ValueKey('share-${person.name}'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight:
                                        isSelected
                                            ? FontWeight.w500
                                            : FontWeight.w400,
                                    color:
                                        isSelected
                                            ? _getDarkenedColor(
                                              person.color,
                                              0.3,
                                            )
                                            : Colors.grey.shade600,
                                  ),
                                ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Custom painter for pulsing effect
class PulsePainter extends CustomPainter {
  final Color color;
  final double progress;

  PulsePainter({required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Create multiple pulse waves
    for (int i = 0; i < 3; i++) {
      final pulseProgress = (progress + (i * 0.2)) % 1.0;

      if (pulseProgress < 0.01) continue;

      final maxRadius = 22.0;
      final radius = maxRadius * pulseProgress;
      final opacity = (1.0 - pulseProgress) * 0.6;

      final paint =
          Paint()
            ..color = color.withOpacity(opacity)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5;

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(PulsePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
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
