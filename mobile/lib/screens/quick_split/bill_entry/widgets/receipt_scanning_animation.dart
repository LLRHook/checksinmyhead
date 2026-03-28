// Billington: Privacy-first receipt splitting
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

import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';

/// Full-screen scanning animation shown while the receipt API processes.
///
/// Displays the receipt photo inside a frosted glass bubble with pulsing glow,
/// floating particles, a gentle bobbing motion, and a scanning shimmer line.
/// When [isComplete] transitions to true, plays a dismiss animation and
/// calls [onDismissed].
class ReceiptScanningAnimation extends StatefulWidget {
  final String imagePath;
  final bool isComplete;
  final VoidCallback? onDismissed;

  const ReceiptScanningAnimation({
    super.key,
    required this.imagePath,
    this.isComplete = false,
    this.onDismissed,
  });

  @override
  State<ReceiptScanningAnimation> createState() =>
      _ReceiptScanningAnimationState();
}

class _ReceiptScanningAnimationState extends State<ReceiptScanningAnimation>
    with TickerProviderStateMixin {
  // Pulse glow breathing (repeating, 2.5s)
  late AnimationController _pulseController;
  // Scanning line sweep (repeating, 3s)
  late AnimationController _scanController;
  // Particle drift (continuous, 6s)
  late AnimationController _particleController;
  // Gentle float/bob (repeating, 3.5s)
  late AnimationController _floatController;
  // Entry (one-shot, 800ms)
  late AnimationController _entryController;
  // Dismiss pop (one-shot, 400ms)
  late AnimationController _dismissController;

  late List<_Particle> _particles;
  late FileImage _fileImage;
  bool _dismissed = false;

  @override
  void initState() {
    _fileImage = FileImage(File(widget.imagePath));
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);

    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6000),
    )..repeat();

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    )..repeat(reverse: true);

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _dismissController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _dismissController.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_dismissed) {
        _dismissed = true;
        widget.onDismissed?.call();
      }
    });

    // Generate particles — mix of small ambient + larger glowing ones
    final rng = Random(42);
    _particles = List.generate(30, (i) {
      final isLarge = i < 6; // first 6 are larger accent particles
      return _Particle(
        x: rng.nextDouble(),
        speed: isLarge ? 0.2 + rng.nextDouble() * 0.3 : 0.3 + rng.nextDouble() * 0.7,
        size: isLarge ? 4.0 + rng.nextDouble() * 5.0 : 1.5 + rng.nextDouble() * 2.5,
        opacity: isLarge ? 0.25 + rng.nextDouble() * 0.2 : 0.1 + rng.nextDouble() * 0.25,
        phase: rng.nextDouble(),
        isGlowing: isLarge,
      );
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _entryController.forward();
    });
  }

  @override
  void didUpdateWidget(ReceiptScanningAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isComplete && !oldWidget.isComplete && !_dismissed) {
      _dismissController.forward();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scanController.dispose();
    _particleController.dispose();
    _floatController.dispose();
    _entryController.dispose();
    _dismissController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenSize = MediaQuery.of(context).size;

    final bubbleWidth = screenSize.width * 0.62;
    final bubbleHeight = bubbleWidth * 1.38;

    return AnimatedBuilder(
      animation: Listenable.merge([_entryController, _dismissController]),
      builder: (context, child) {
        final entryValue =
            CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic)
                .value;
        final dismissValue =
            CurvedAnimation(parent: _dismissController, curve: Curves.easeInBack)
                .value;

        final scale = entryValue * (1.0 - dismissValue);
        final opacity = entryValue * (1.0 - dismissValue);

        if (opacity <= 0) return const SizedBox.shrink();

        return Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: _buildBackground(
              colorScheme,
              screenSize,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Floating bubble
                  AnimatedBuilder(
                    animation: _floatController,
                    builder: (context, child) {
                      final floatValue = CurvedAnimation(
                        parent: _floatController,
                        curve: Curves.easeInOut,
                      ).value;
                      // Gentle vertical bob: -6 to +6 px
                      final yOffset = (floatValue - 0.5) * 12.0;
                      return Transform.translate(
                        offset: Offset(0, yOffset),
                        child: Transform.scale(
                          scale: scale.clamp(0.0, 1.1),
                          child: _buildGlassBubble(
                            colorScheme,
                            bubbleWidth,
                            bubbleHeight,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 36),
                  // Status text with subtle glow
                  AnimatedOpacity(
                    opacity: _dismissController.isAnimating ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        final textGlow = CurvedAnimation(
                          parent: _pulseController,
                          curve: Curves.easeInOut,
                        ).value;
                        return Text(
                          'Scanning receipt…',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                            shadows: [
                              Shadow(
                                color: colorScheme.primary.withValues(
                                    alpha: 0.3 + textGlow * 0.3),
                                blurRadius: 12 + textGlow * 8,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Dark gradient background with subtle teal radial glow
  // ---------------------------------------------------------------------------
  Widget _buildBackground(
    ColorScheme colorScheme,
    Size screenSize, {
    required Widget child,
  }) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) {
        final pulse = CurvedAnimation(
          parent: _pulseController,
          curve: Curves.easeInOut,
        ).value;
        final bgGlowOpacity = 0.06 + pulse * 0.04;

        return Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0.0, -0.15),
              radius: 0.9,
              colors: [
                colorScheme.primary.withValues(alpha: bgGlowOpacity),
                const Color(0xFF050808),
                Colors.black,
              ],
              stops: const [0.0, 0.55, 1.0],
            ),
          ),
          child: child,
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Glass bubble: image + frost layers + glow + particles + shimmer
  // ---------------------------------------------------------------------------
  Widget _buildGlassBubble(
    ColorScheme colorScheme,
    double width,
    double height,
  ) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulseValue =
            CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut)
                .value;
        final glowRadius = 14.0 + pulseValue * 18.0;

        return Stack(
          alignment: Alignment.center,
          children: [
            // Particles (behind bubble)
            SizedBox(
              width: width + 80,
              height: height + 80,
              child: AnimatedBuilder(
                animation: _particleController,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _BubbleParticlePainter(
                      progress: _particleController.value,
                      color: colorScheme.primary,
                      particles: _particles,
                    ),
                  );
                },
              ),
            ),
            // Outer glow — two layers for depth
            Container(
              width: width + 4,
              height: height + 4,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  // Broad diffuse glow
                  BoxShadow(
                    color: colorScheme.primary
                        .withValues(alpha: 0.12 + pulseValue * 0.12),
                    blurRadius: glowRadius * 3,
                    spreadRadius: glowRadius * 0.5,
                  ),
                  // Tighter bright glow
                  BoxShadow(
                    color: colorScheme.primary
                        .withValues(alpha: 0.08 + pulseValue * 0.08),
                    blurRadius: glowRadius,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
            // Glass bubble
            ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: SizedBox(
                width: width,
                height: height,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Receipt image
                    Image(
                      image: _fileImage,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFF1A2A2A),
                        child: Icon(
                          Icons.receipt_long,
                          size: 48,
                          color: colorScheme.primary.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                    // Heavy frosted glass blur
                    BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 6.0, sigmaY: 6.0),
                      child: Container(color: Colors.transparent),
                    ),
                    // Glass tint layers — creates depth
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withValues(alpha: 0.12),
                            Colors.white.withValues(alpha: 0.04),
                            colorScheme.primary.withValues(alpha: 0.06),
                          ],
                        ),
                      ),
                    ),
                    // Subtle inner image showing through (reduced blur center)
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image(
                          image: _fileImage,
                          fit: BoxFit.cover,
                          opacity: AlwaysStoppedAnimation(0.35 + pulseValue * 0.1),
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                    // Scanning shimmer line
                    _buildScanningLine(colorScheme),
                    // Glass edge highlight — top/left bright, bottom/right dark
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        border: Border(
                          top: BorderSide(
                            color: Colors.white.withValues(
                                alpha: 0.25 + pulseValue * 0.1),
                            width: 1.0,
                          ),
                          left: BorderSide(
                            color: Colors.white.withValues(
                                alpha: 0.15 + pulseValue * 0.05),
                            width: 1.0,
                          ),
                          bottom: BorderSide(
                            color: Colors.white.withValues(alpha: 0.05),
                            width: 1.0,
                          ),
                          right: BorderSide(
                            color: Colors.white.withValues(alpha: 0.05),
                            width: 1.0,
                          ),
                        ),
                      ),
                    ),
                    // Top specular highlight
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: height * 0.35,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(28)),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withValues(alpha: 0.08),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Shimmer scanning line — wider and more dramatic
  // ---------------------------------------------------------------------------
  Widget _buildScanningLine(ColorScheme colorScheme) {
    return AnimatedBuilder(
      animation: _scanController,
      builder: (context, child) {
        final position = _scanController.value;
        return Positioned.fill(
          child: ShaderMask(
            blendMode: BlendMode.srcOver,
            shaderCallback: (Rect bounds) {
              return LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  colorScheme.primary.withValues(alpha: 0.15),
                  Colors.white.withValues(alpha: 0.25),
                  colorScheme.primary.withValues(alpha: 0.15),
                  Colors.transparent,
                ],
                stops: [
                  (position - 0.10).clamp(0.0, 1.0),
                  (position - 0.03).clamp(0.0, 1.0),
                  position,
                  (position + 0.03).clamp(0.0, 1.0),
                  (position + 0.10).clamp(0.0, 1.0),
                ],
              ).createShader(bounds);
            },
            child: Container(color: Colors.transparent),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Particle system — small ambient + larger glowing orbs
// ---------------------------------------------------------------------------

class _Particle {
  final double x;
  final double speed;
  final double size;
  final double opacity;
  final double phase;
  final bool isGlowing;

  const _Particle({
    required this.x,
    required this.speed,
    required this.size,
    required this.opacity,
    required this.phase,
    this.isGlowing = false,
  });
}

class _BubbleParticlePainter extends CustomPainter {
  final double progress;
  final Color color;
  final List<_Particle> particles;

  _BubbleParticlePainter({
    required this.progress,
    required this.color,
    required this.particles,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final t = (progress * p.speed + p.phase) % 1.0;
      final y = size.height * (1.0 - t);

      // Horizontal wobble — larger for glowing particles
      final wobble = p.isGlowing ? 14.0 : 6.0;
      final x = size.width * p.x +
          sin(t * 2 * pi + p.phase * pi) * wobble;

      // Fade envelope
      final fadeIn = (t * 3.0).clamp(0.0, 1.0);
      final fadeOut = ((1.0 - t) * 3.0).clamp(0.0, 1.0);
      final alpha = p.opacity * fadeIn * fadeOut;

      if (p.isGlowing) {
        // Draw a soft glow halo behind larger particles
        final glowPaint = Paint()
          ..color = color.withValues(alpha: alpha * 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
        canvas.drawCircle(Offset(x, y), p.size * 2.0, glowPaint);
      }

      final paint = Paint()
        ..color = color.withValues(alpha: alpha)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(x, y), p.size, paint);
    }
  }

  @override
  bool shouldRepaint(_BubbleParticlePainter oldDelegate) =>
      progress != oldDelegate.progress;
}
