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

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:checks_frontend/screens/settings/widgets/hsv_color_wheel_painter.dart';
import 'package:checks_frontend/screens/settings/utils/animation_utils.dart';
import 'package:checks_frontend/screens/quick_split/item_assignment/utils/color_utils.dart';

/// Bottom sheet color picker with an HSV color wheel.
///
/// Layout (top to bottom):
/// 1. Drag handle
/// 2. Title: "Custom Color"
/// 3. Hue ring + SV square (with bouncy entrance animation)
/// 4. Live preview bar with hex value
/// 5. Collapsible hex input
/// 6. Full-width "Apply" button
class ColorPickerSheet extends StatefulWidget {
  /// The initial color to display in the picker.
  final Color? initialColor;

  /// Called when the user taps Apply with the selected color.
  final ValueChanged<Color> onColorSelected;

  const ColorPickerSheet({
    super.key,
    this.initialColor,
    required this.onColorSelected,
  });

  @override
  State<ColorPickerSheet> createState() => _ColorPickerSheetState();
}

class _ColorPickerSheetState extends State<ColorPickerSheet>
    with SingleTickerProviderStateMixin {
  late double _hue;
  late double _saturation;
  late double _brightness;

  bool _showHexInput = false;
  late TextEditingController _hexController;
  bool _isUpdatingFromWheel = false;

  // Entrance animation
  late AnimationController _entranceController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  // Wheel layout constants
  static const double _wheelSize = 240;
  static const double _ringWidth = 24;
  static const double _svGap = 12; // gap between inner ring and SV square

  double get _outerRadius => _wheelSize / 2;
  double get _innerRadius => _outerRadius - _ringWidth;
  double get _svSquareSize => (_innerRadius - _svGap) * 2 * 0.707; // inscribed square

  @override
  void initState() {
    super.initState();

    // Convert initial color to HSV
    final hsv = widget.initialColor != null
        ? HSVColor.fromColor(widget.initialColor!)
        : HSVColor.fromAHSV(1, 180, 0.8, 0.8);
    _hue = hsv.hue;
    _saturation = hsv.saturation;
    _brightness = hsv.value;

    _hexController = TextEditingController(text: _currentHexString);

    // Set up entrance animation
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: BouncyEntranceCurve(),
      ),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: Curves.easeOut,
      ),
    );
    _entranceController.forward();
  }

  @override
  void dispose() {
    _hexController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  Color get _currentColor =>
      HSVColor.fromAHSV(1, _hue, _saturation, _brightness).toColor();

  String get _currentHexString =>
      _currentColor.toARGB32().toRadixString(16).substring(2).toUpperCase();

  void _updateFromHex(String hex) {
    final clean = hex.replaceAll('#', '').trim();
    if (clean.length != 6) return;
    final value = int.tryParse(clean, radix: 16);
    if (value == null) return;

    final color = Color(0xFF000000 | value);
    final hsv = HSVColor.fromColor(color);
    setState(() {
      _hue = hsv.hue;
      _saturation = hsv.saturation;
      _brightness = hsv.value;
    });
  }

  void _syncHexField() {
    if (!_isUpdatingFromWheel) return;
    _hexController.text = _currentHexString;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textColor = ColorUtils.getContrastiveTextColor(_currentColor);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          top: 20,
          left: 16,
          right: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Center(
              child: ExcludeSemantics(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),

            // Title
            const Padding(
              padding: EdgeInsets.only(bottom: 20),
              child: Text(
                'Custom Color',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // Color wheel with entrance animation
            FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: SizedBox(
                  width: _wheelSize,
                  height: _wheelSize,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Hue ring (full size, gesture on ring area)
                      GestureDetector(
                        onPanStart: (d) => _onRingPan(d.localPosition),
                        onPanUpdate: (d) => _onRingPan(d.localPosition),
                        onTapDown: (d) => _onRingPan(d.localPosition),
                        child: CustomPaint(
                          size: Size(_wheelSize, _wheelSize),
                          painter: HueRingPainter(
                            hue: _hue,
                            innerRadius: _innerRadius,
                            outerRadius: _outerRadius,
                          ),
                        ),
                      ),

                      // SV square (centered inside ring)
                      GestureDetector(
                        onPanStart: (d) => _onSVPan(d.localPosition),
                        onPanUpdate: (d) => _onSVPan(d.localPosition),
                        onTapDown: (d) => _onSVPan(d.localPosition),
                        child: CustomPaint(
                          size: Size(_svSquareSize, _svSquareSize),
                          painter: SaturationBrightnessPainter(
                            hue: _hue,
                            saturation: _saturation,
                            brightness: _brightness,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Live preview bar
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 48,
              width: double.infinity,
              decoration: BoxDecoration(
                color: _currentColor,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                '#$_currentHexString',
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Collapsible hex input toggle
            GestureDetector(
              onTap: () => setState(() => _showHexInput = !_showHexInput),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  _showHexInput ? 'Hide hex code' : 'Enter hex code',
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

            // Animated hex input field
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: _showHexInput
                  ? Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: TextField(
                        controller: _hexController,
                        textCapitalization: TextCapitalization.characters,
                        maxLength: 6,
                        decoration: InputDecoration(
                          prefixText: '#  ',
                          prefixStyle: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          hintText: '328983',
                          counterText: '',
                          filled: true,
                          fillColor:
                              Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white.withValues(alpha: .1)
                                  : Colors.black.withValues(alpha: .05),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: colorScheme.primary,
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                        onChanged: (value) {
                          _updateFromHex(value);
                        },
                      ),
                    )
                  : const SizedBox.shrink(),
            ),

            const SizedBox(height: 16),

            // Apply button (matches payment_method_sheet style)
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  Navigator.pop(context);
                  widget.onColorSelected(_currentColor);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Apply',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// Handles pan/tap gestures on the hue ring.
  void _onRingPan(Offset localPosition) {
    final center = Offset(_wheelSize / 2, _wheelSize / 2);
    final dx = localPosition.dx - center.dx;
    final dy = localPosition.dy - center.dy;
    final distance = sqrt(dx * dx + dy * dy);

    // Only respond to touches within the ring area (with some tolerance)
    if (distance < _innerRadius - 10 || distance > _outerRadius + 10) return;

    // Calculate angle and convert to hue (0–360), with 0° at top
    var angle = atan2(dy, dx) * 180 / pi + 90;
    if (angle < 0) angle += 360;

    _isUpdatingFromWheel = true;
    setState(() {
      _hue = angle.clamp(0, 360).toDouble();
    });
    _syncHexField();
    _isUpdatingFromWheel = false;
    HapticFeedback.selectionClick();
  }

  /// Handles pan/tap gestures on the SV square.
  void _onSVPan(Offset localPosition) {
    _isUpdatingFromWheel = true;
    setState(() {
      _saturation = (localPosition.dx / _svSquareSize).clamp(0, 1).toDouble();
      _brightness =
          (1 - localPosition.dy / _svSquareSize).clamp(0, 1).toDouble();
    });
    _syncHexField();
    _isUpdatingFromWheel = false;
  }
}

/// Shows the color picker as a modal bottom sheet.
///
/// Returns the selected [Color] via the [onColorSelected] callback.
Future<void> showColorPickerSheet({
  required BuildContext context,
  Color? initialColor,
  required ValueChanged<Color> onColorSelected,
}) {
  return showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    isScrollControlled: true,
    builder: (context) {
      return ColorPickerSheet(
        initialColor: initialColor,
        onColorSelected: onColorSelected,
      );
    },
  );
}
