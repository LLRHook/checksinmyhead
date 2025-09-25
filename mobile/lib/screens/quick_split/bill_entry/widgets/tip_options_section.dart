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

import 'package:checks_frontend/screens/quick_split/bill_entry/components/input_decoration.dart';
import 'package:checks_frontend/screens/quick_split/bill_entry/components/section_card.dart';
import 'package:checks_frontend/screens/quick_split/bill_entry/models/bill_data.dart';
import 'package:checks_frontend/screens/quick_split/bill_entry/utils/currency_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

/// TipOptionsSection - Controls for configuring tip amount
///
/// Provides two modes for setting the tip:
/// 1. Percentage-based (with slider and quick selection buttons)
/// 2. Custom amount (with direct currency input)
///
/// Features:
/// - Animated toggle between percentage and custom modes
/// - Interactive slider with visual feedback for selecting tip percentage
/// - Quick-select percentage buttons for common tip values
/// - Theme-aware styling that adapts to light and dark modes
/// - Haptic feedback for improved user experience
class TipOptionsSection extends StatelessWidget {
  const TipOptionsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final billData = Provider.of<BillData>(context);
    final brightness = Theme.of(context).brightness;

    // Slightly different background color for toggle based on theme
    final toggleBgColor =
        brightness == Brightness.dark
            ? colorScheme.surfaceContainerHighest
            : colorScheme.surfaceContainerHighest.withValues(alpha: .5);

    return SectionCard(
      title: 'Tip Options',
      icon: Icons.volunteer_activism,
      children: [
        // Align the mode toggle to the right
        Row(
          children: [
            const Spacer(),
            // Segmented control for switching between percentage and custom modes
            Container(
              height: 36,
              decoration: BoxDecoration(
                color: toggleBgColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ToggleOption(
                    title: 'Percentage',
                    isSelected: !billData.useCustomTipAmount,
                    onTap: () {
                      billData.toggleCustomTipAmount(false);
                      HapticFeedback.selectionClick();
                    },
                  ),
                  _ToggleOption(
                    title: 'Custom',
                    isSelected: billData.useCustomTipAmount,
                    onTap: () {
                      billData.toggleCustomTipAmount(true);
                      HapticFeedback.selectionClick();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Show either custom amount field or percentage controls based on selected mode
        if (billData.useCustomTipAmount)
          TextFormField(
            controller: billData.customTipController,
            decoration: AppInputDecoration.buildInputDecoration(
              context: context,
              labelText: 'Tip Amount',
              prefixText: '\$',
              hintText: '0.00',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [CurrencyFormatter.currencyFormatter],
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurface,
            ),
          ),

        // Percentage-based tip controls
        if (!billData.useCustomTipAmount) ...[
          // Interactive slider with current percentage display
          _TipPercentageSlider(
            tipPercentage: billData.tipPercentage,
            color: colorScheme.primary,
            onChanged: (value) {
              billData.setTipPercentage(value);
              // Provide subtle haptic feedback at 5% intervals
              if (value.toInt() % 5 == 0) {
                HapticFeedback.selectionClick();
              }
            },
          ),

          const SizedBox(height: 16),

          // Quick-select buttons for common percentages
          _QuickTipPercentageButtons(
            tipPercentage: billData.tipPercentage,
            onPercentageSelected: (percentage) {
              billData.setTipPercentage(percentage);
              HapticFeedback.selectionClick();
            },
          ),

          const SizedBox(height: 20),
        ],
      ],
    );
  }
}

/// Toggle option button for switching between percentage and custom tip modes
///
/// Part of a segmented control that highlights the currently selected mode
/// and provides a visual transition when switching modes.
class _ToggleOption extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _ToggleOption({
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    // Use dark text on bright backgrounds for better contrast in dark mode
    final selectedTextColor =
        brightness == Brightness.dark
            ? Colors.black.withValues(alpha: .9)
            : Colors.white;

    // Dimmed text for unselected state
    final unselectedTextColor =
        brightness == Brightness.dark
            ? colorScheme.onSurface.withValues(alpha: .7)
            : colorScheme.onSurfaceVariant;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? selectedTextColor : unselectedTextColor,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

/// Interactive slider for selecting tip percentage
///
/// Displays the current percentage value and provides a customized
/// slider with theme-appropriate styling for adjusting the value.
class _TipPercentageSlider extends StatelessWidget {
  final double tipPercentage;
  final Color color;
  final ValueChanged<double> onChanged;

  const _TipPercentageSlider({
    required this.tipPercentage,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    // Softer background for the container based on theme
    final containerBgColor =
        brightness == Brightness.dark
            ? color.withValues(alpha: .15)
            : color.withValues(alpha: .1);

    // Slightly adjust text color for dark mode
    final percentageTextColor =
        brightness == Brightness.dark ? color.withValues(alpha: .9) : color;

    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: containerBgColor,
        borderRadius: BorderRadius.circular(25),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Display current percentage value
          Text(
            '${tipPercentage.toInt()}%',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: percentageTextColor,
            ),
          ),
          Expanded(
            // Customized slider with theme-appropriate styling
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: color,
                inactiveTrackColor: color.withValues(
                  alpha: brightness == Brightness.dark ? 0.3 : 0.2,
                ),
                thumbColor: color,
                overlayColor: color.withValues(alpha: .2),
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 8,
                  elevation: 2,
                ),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              ),
              child: Slider(
                value: tipPercentage,
                min: 0,
                max: 99,
                divisions: 99, // Allow 1% increments
                onChanged: (value) {
                  // Round to nearest integer to ensure precise selection
                  onChanged(value.roundToDouble());
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Quick-select buttons for common tip percentages
///
/// Displays a row of buttons for commonly used tip percentages
/// with visual highlighting for the currently selected value.
class _QuickTipPercentageButtons extends StatelessWidget {
  final double tipPercentage;
  final ValueChanged<double> onPercentageSelected;

  const _QuickTipPercentageButtons({
    required this.tipPercentage,
    required this.onPercentageSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    // Theme-aware colors for selected and unselected states
    final selectedTextColor =
        brightness == Brightness.dark
            ? Colors.black.withValues(alpha: .9)
            : Colors.white;

    final unselectedTextColor =
        brightness == Brightness.dark
            ? colorScheme.onSurface
            : colorScheme.onSurface;

    final unselectedBgColor =
        brightness == Brightness.dark
            ? colorScheme.surfaceContainerHighest
            : colorScheme.surface;

    final borderColor =
        brightness == Brightness.dark
            ? colorScheme.outline.withValues(alpha: .3)
            : colorScheme.outline.withValues(alpha: .5);

    // Common tip percentages to display as quick-select options
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children:
          [15, 18, 20, 25, 30].map((percentage) {
            final isSelected = tipPercentage == percentage;
            return GestureDetector(
              onTap: () => onPercentageSelected(percentage.toDouble()),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? colorScheme.primary : unselectedBgColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? colorScheme.primary : borderColor,
                    width: 1.5,
                  ),
                  // Add subtle elevation shadow only to selected button
                  boxShadow:
                      isSelected
                          ? [
                            BoxShadow(
                              color: colorScheme.primary.withValues(
                                alpha:
                                    brightness == Brightness.dark ? 0.15 : 0.2,
                              ),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ]
                          : null,
                ),
                child: Text(
                  '$percentage%',
                  style: TextStyle(
                    color: isSelected ? selectedTextColor : unselectedTextColor,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
    );
  }
}
