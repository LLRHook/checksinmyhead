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
          // Instruction text
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 14,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Tap: quick assign • Long press: birthday',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
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

  Widget _buildParticipantChip({
    required Person person,
    required bool isSelected,
    required bool isBirthdayPerson,
    required double share,
  }) {
    // Animation controller for confetti
    final birthdayColor = Colors.pink.shade300;
    
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
            color: isBirthdayPerson 
                ? birthdayColor.withOpacity(0.15)
                : isSelected 
                    ? person.color.withOpacity(0.15) 
                    : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(isSelected ? 14 : 12),
            border: Border.all(
              color: isBirthdayPerson
                  ? birthdayColor
                  : isSelected 
                      ? person.color 
                      : Colors.grey.shade300,
              width: (isBirthdayPerson || isSelected) ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isBirthdayPerson
                    ? birthdayColor.withOpacity(0.35)
                    : isSelected 
                        ? person.color.withOpacity(0.35)
                        : Colors.black.withOpacity(0.02),
                blurRadius: (isBirthdayPerson || isSelected) ? 10 : 4,
                spreadRadius: (isBirthdayPerson || isSelected) ? 1 : 0,
                offset: (isBirthdayPerson || isSelected) 
                    ? const Offset(0, 3)
                    : const Offset(0, 1),
              )
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Avatar with animations
                AnimatedScale(
                  scale: (isBirthdayPerson || isSelected) ? 1.1 : 1.0,
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.elasticOut,
                  child: AnimatedRotation(
                    turns: (isBirthdayPerson || isSelected) ? 0.05 : 0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutBack,
                    child: Stack(
                      children: [
                        // Birthday confetti animation
                        if (isBirthdayPerson)
                          TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: 0.0, end: 1.0),
                            duration: const Duration(milliseconds: 2000),
                            curve: Curves.easeOut,
                            builder: (context, value, child) {
                              return RepaintBoundary(
                                child: CustomPaint(
                                  size: const Size(36, 36),
                                  painter: ConfettiPainter(
                                    progress: value,
                                    baseColor: birthdayColor,
                                  ),
                                ),
                              );
                            },
                          ),
                          
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
                          
                        // Avatar or cake icon for birthday
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: isBirthdayPerson 
                              ? birthdayColor
                              : isSelected
                                  ? person.color
                                  : person.color.withOpacity(0.9),
                          child: isBirthdayPerson
                              ? const Icon(
                                  Icons.cake,
                                  color: Colors.white,
                                  size: 16,
                                )
                              : AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 250),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: isSelected ? 14 : 12,
                                  ),
                                  child: Text(person.name[0].toUpperCase()),
                                ),
                        ),
                      ],
                    ),
                  ),
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
                          fontWeight: (isBirthdayPerson || isSelected) ? FontWeight.w600 : FontWeight.w500,
                          color: isBirthdayPerson 
                              ? birthdayColor
                              : isSelected 
                                  ? person.color 
                                  : Colors.grey.shade800,
                        ),
                        child: Text(
                          person.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      
                      // Share amount or birthday text
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 250),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: (isBirthdayPerson || isSelected) ? FontWeight.w500 : FontWeight.w400,
                          color: isBirthdayPerson 
                              ? birthdayColor
                              : isSelected
                                  ? person.color.withOpacity(0.8)
                                  : Colors.grey.shade600,
                        ),
                        child: isBirthdayPerson
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Flexible(
                                    child: Text(
                                      'Birthday!',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  SizedBox(width: 2),
                                  Icon(
                                    Icons.celebration,
                                    size: 10,
                                    color: Colors.amber,
                                  ),
                                ],
                              )
                            : Text(
                                "\$" + share.toStringAsFixed(2),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
      
      final paint = Paint()
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

// Custom painter for confetti effect
class ConfettiPainter extends CustomPainter {
  final double progress;
  final Color baseColor;
  
  ConfettiPainter({required this.progress, required this.baseColor});
  
  @override
  void paint(Canvas canvas, Size size) {
    final random = DateTime.now().millisecondsSinceEpoch;
    final center = Offset(size.width / 2, size.height / 2);
    
    // Draw 20 confetti pieces
    for (int i = 0; i < 20; i++) {
      // Pseudo-random angle and distance
      final angle = (i * 18 + random % 10) * 0.0174533; // Convert to radians
      final distance = 15.0 + (i % 3) * 5 + (random % 5);
      
      // Calculate position based on progress (flying outward)
      final offsetDistance = distance * progress;
      final gravity = 10.0 * progress * progress; // Parabolic path
      
      final x = center.dx + offsetDistance * cos(angle);
      final y = center.dy + offsetDistance * sin(angle) + gravity;
      
      // Skip if out of bounds
      if (y > size.height || x < 0 || x > size.width) continue;
      
      // Randomly alternate colors
      final confettiColor = i % 3 == 0 
          ? Colors.yellow 
          : i % 3 == 1 
              ? Colors.pink 
              : Colors.blue;
      
      // Vary size and opacity based on progress
      final confettiSize = 2.0 + (i % 3) * 1.5;
      final opacity = 1.0 - progress;
      
      final paint = Paint()
        ..color = confettiColor.withOpacity(opacity)
        ..style = PaintingStyle.fill;
      
      // Draw confetti piece
      canvas.drawCircle(Offset(x, y), confettiSize, paint);
      
      // Some pieces are rectangular
      if (i % 5 == 0) {
        final rect = Rect.fromCenter(
          center: Offset(x, y),
          width: confettiSize * 3,
          height: confettiSize,
        );
        
        // Rotate the canvas for the rectangle
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(angle * 5 * progress);
        canvas.translate(-x, -y);
        
        canvas.drawRect(rect, paint);
        canvas.restore();
      }
    }
  }
  
  @override
  bool shouldRepaint(ConfettiPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}