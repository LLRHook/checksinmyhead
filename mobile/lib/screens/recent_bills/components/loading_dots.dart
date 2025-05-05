import 'package:flutter/material.dart';

class LoadingDots extends StatefulWidget {
  final Color color;
  final double size;
  final double spacing;

  const LoadingDots({
    Key? key,
    required this.color,
    this.size = 4.0,
    this.spacing = 2.0,
  }) : super(key: key);

  @override
  State<LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<LoadingDots>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();

    // A single controller for the entire animation sequence
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    // Create sequential animations for each dot
    _animations = List.generate(3, (index) {
      // Each dot has its own part of the animation cycle
      final start = index * 0.2;
      final end = start + 0.4;

      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _controller,
          // Use interval to control when each dot appears in the sequence
          curve: Interval(start, end, curve: Curves.easeInOut),
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 3 * widget.size + 4 * widget.spacing,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (index) {
          return AnimatedBuilder(
            animation: _animations[index],
            builder: (context, child) {
              // Calculate opacity for each dot based on animation value
              // This creates the fade in/out effect
              final opacity =
                  _animations[index].value < 0.1
                      ? _animations[index].value * 10
                      : _animations[index].value > 0.9
                      ? (1.0 - _animations[index].value) * 10
                      : 1.0;

              return Container(
                margin: EdgeInsets.symmetric(horizontal: widget.spacing / 2),
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(opacity),
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
