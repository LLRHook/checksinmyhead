import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// A widget that displays a step-by-step tutorial overlay with navigation
// and progress indicators. Designed to guide users through app features.
class TutorialOverlay extends StatefulWidget {
  // List of tutorial steps to display in sequence
  final List<TutorialStep> steps;

  // Callback function when tutorial is completed or dismissed
  final VoidCallback onComplete;

  // Whether to show the close button in the top-right corner
  final bool showCloseButton;

  const TutorialOverlay({
    super.key,
    required this.steps,
    required this.onComplete,
    this.showCloseButton = true,
  });

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay>
    with SingleTickerProviderStateMixin {
  // Current step index being displayed
  int _currentStep = 0;

  // Controller for page transitions between steps
  late PageController _pageController;

  // Progress value between 0.0 and 1.0
  double _progressValue = 0.0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _updateProgress();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // Updates the progress indicator based on current step
  void _updateProgress() {
    setState(() {
      _progressValue = (_currentStep + 1) / widget.steps.length;
    });
  }

  // Advances to the next tutorial step or completes if on last step
  void _nextStep() {
    // Add haptic feedback for a premium feel
    HapticFeedback.lightImpact();

    if (_currentStep < widget.steps.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() {
        _currentStep++;
        _updateProgress();
      });
    } else {
      _close();
    }
  }

  // Returns to the previous tutorial step if not on first step
  void _previousStep() {
    // Add haptic feedback for a premium feel
    HapticFeedback.lightImpact();

    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() {
        _currentStep--;
        _updateProgress();
      });
    }
  }

  // Closes the tutorial and calls the onComplete callback
  void _close() {
    HapticFeedback.mediumImpact();
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    // Theme-aware colors
    final dialogBgColor =
        brightness == Brightness.dark ? colorScheme.surface : Colors.white;

    final progressTextColor =
        brightness == Brightness.dark
            ? colorScheme.onSurface.withValues(alpha: .7)
            : Colors.grey[600];

    final closeButtonColor =
        brightness == Brightness.dark ? Colors.grey[500] : Colors.grey[400];

    final progressTrackColor =
        brightness == Brightness.dark
            ? colorScheme.surfaceContainerHighest
            : Colors.grey.shade200;

    final shadowColor =
        brightness == Brightness.dark
            ? Colors.black.withValues(alpha: .3)
            : Colors.black.withValues(alpha: .2);

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // Semi-transparent background
          GestureDetector(
            onTap: widget.showCloseButton ? _close : null,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: .6),
              ),
            ),
          ),

          // Tutorial content
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: dialogBgColor,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: shadowColor,
                    blurRadius: 20,
                    spreadRadius: 5,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top bar with close button and progress
                  Row(
                    children: [
                      // Progress text
                      Text(
                        'Step ${_currentStep + 1} of ${widget.steps.length}',
                        style: TextStyle(
                          fontSize: 14,
                          color: progressTextColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      const Spacer(),

                      // Percentage indicator
                      Text(
                        '${(_progressValue * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 14,
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(width: 10),

                      // Close button
                      if (widget.showCloseButton)
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: _close,
                            child: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: Icon(
                                Icons.close,
                                color: closeButtonColor,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),

                  // Progress bar that animates smoothly
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(
                      begin: (_currentStep) / widget.steps.length,
                      end: _progressValue,
                    ),
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    builder:
                        (context, value, _) => Padding(
                          padding: const EdgeInsets.only(
                            top: 8.0,
                            bottom: 20.0,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: value,
                              backgroundColor: progressTrackColor,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                colorScheme.primary,
                              ),
                              minHeight: 6,
                            ),
                          ),
                        ),
                  ),

                  // Content pages that slide
                  SizedBox(
                    height: 220, // Fixed height to prevent layout shifts
                    child: PageView.builder(
                      controller: _pageController,
                      physics:
                          const NeverScrollableScrollPhysics(), // Disable swiping
                      itemCount: widget.steps.length,
                      onPageChanged: (index) {
                        setState(() {
                          _currentStep = index;
                          _updateProgress();
                        });
                      },
                      itemBuilder: (context, index) {
                        final step = widget.steps[index];
                        return _buildStepContent(step, colorScheme, brightness);
                      },
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Navigation buttons with modern styling
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Back button
                      if (_currentStep > 0)
                        OutlinedButton(
                          onPressed: _previousStep,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colorScheme.primary,
                            side: BorderSide(
                              color: colorScheme.primary.withValues(alpha: .5),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.arrow_back_ios_new, size: 16),
                              SizedBox(width: 8),
                              Text('Back'),
                            ],
                          ),
                        )
                      else
                        const SizedBox.shrink(),

                      // Next/Done button
                      ElevatedButton(
                        onPressed: _nextStep,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor:
                              brightness == Brightness.dark
                                  ? Colors.black.withValues(
                                    alpha: 0.9,
                                  ) // Better contrast in dark mode
                                  : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _currentStep < widget.steps.length - 1
                                  ? 'Next'
                                  : 'Got It!',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              _currentStep < widget.steps.length - 1
                                  ? Icons.arrow_forward_ios
                                  : Icons.check,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Builds the content widget for an individual tutorial step
  Widget _buildStepContent(
    TutorialStep step,
    ColorScheme colorScheme,
    Brightness brightness,
  ) {
    // Theme-aware colors
    final titleColor = colorScheme.onSurface;
    final descriptionColor =
        brightness == Brightness.dark
            ? colorScheme.onSurface.withValues(alpha: .9)
            : colorScheme.onSurface;

    final iconBgColor = colorScheme.primary.withValues(
      alpha: brightness == Brightness.dark ? 0.2 : 0.1,
    );
    final iconShadowColor = colorScheme.primary.withValues(
      alpha: brightness == Brightness.dark ? 0.2 : 0.1,
    );

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title with icon in a modern style
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: iconShadowColor,
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(step.icon, color: colorScheme.primary, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  step.title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                    color: titleColor,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Step content with modern typography
          Text(
            step.description,
            style: TextStyle(
              fontSize: 16,
              height: 1.5,
              letterSpacing: 0.1,
              color: descriptionColor,
            ),
          ),

          // Image if provided
          if (step.image != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(step.image!, height: 120, fit: BoxFit.cover),
              ),
            ),
        ],
      ),
    );
  }
}

// A data class representing a single step in a tutorial sequence
class TutorialStep {
  // The title displayed at the top of the step
  final String title;

  // Detailed description explaining the feature
  final String description;

  // Icon displayed next to the title
  final IconData icon;

  // Optional image path for visual illustrations
  final String? image;

  const TutorialStep({
    required this.title,
    required this.description,
    required this.icon,
    this.image,
  });
}

// A button widget that shows a help icon with an optional notification badge
// Used to trigger the tutorial overlay from various parts of the app
class TutorialButton extends StatelessWidget {
  // Callback when the button is pressed
  final VoidCallback onPressed;

  // Optional badge to indicate new or unread tutorials
  final Widget? badge;

  const TutorialButton({super.key, required this.onPressed, this.badge});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    // Theme-aware badge color
    final badgeColor =
        brightness == Brightness.dark
            ? Colors
                .red
                .shade300 // Lighter red for dark mode
            : Colors.red;

    return Stack(
      children: [
        Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.hardEdge,
          child: IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: onPressed,
            tooltip: 'How to use',
            color: colorScheme.primary,
            splashRadius: 24,
          ),
        ),
        if (badge != null)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: badgeColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}

// Helper function to show the tutorial overlay with a fade-in animation
// Makes it easy to display tutorials from anywhere in the app
void showTutorialOverlay(
  BuildContext context, {
  required List<TutorialStep> steps,
  bool barrierDismissible = true,
}) {
  // Simplified entrance animation
  showGeneralDialog(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: 'Tutorial',
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, animation, secondaryAnimation) {
      return TutorialOverlay(
        steps: steps,
        onComplete: () => Navigator.of(context).pop(),
        showCloseButton: barrierDismissible,
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      // Just a simple fade for the entrance
      return FadeTransition(opacity: animation, child: child);
    },
  );
}
