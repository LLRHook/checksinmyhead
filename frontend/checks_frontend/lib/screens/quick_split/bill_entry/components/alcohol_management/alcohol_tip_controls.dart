import 'package:checks_frontend/screens/quick_split/bill_entry/models/bill_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AlcoholTipControls extends StatelessWidget {
  final BillData billData;
  final ColorScheme colorScheme;

  const AlcoholTipControls({
    Key? key,
    required this.billData,
    required this.colorScheme,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Enable alcohol tip toggle
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceVariant.withOpacity(0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outline.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: SwitchListTile(
            title: Text(
              'Different tip for alcohol?',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            subtitle: Text(
              'Apply a special tip rate for alcoholic items',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
            ),
            value: billData.useDifferentTipForAlcohol,
            onChanged: (value) {
              billData.toggleDifferentTipForAlcohol(value);
              HapticFeedback.selectionClick();
            },
            activeColor: colorScheme.tertiary,
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),

        // Only show alcohol tip percentage if different tip for alcohol is enabled
        if (billData.useDifferentTipForAlcohol) ...[
          SizedBox(height: 24),

          // Alcohol tip slider
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Alcohol Tip Percentage',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              SizedBox(height: 12),
              Container(
                height: 50,
                decoration: BoxDecoration(
                  color: colorScheme.tertiary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(25),
                ),
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      alignment: Alignment.center,
                      child: Text(
                        '${billData.alcoholTipPercentage.toInt()}%',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.tertiary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: colorScheme.tertiary,
                          inactiveTrackColor: colorScheme.tertiary.withOpacity(
                            0.2,
                          ),
                          thumbColor: colorScheme.tertiary,
                          overlayColor: colorScheme.tertiary.withOpacity(0.2),
                          trackHeight: 4,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 8,
                            elevation: 2,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 16,
                          ),
                        ),
                        child: Slider(
                          value: billData.alcoholTipPercentage,
                          min: 0,
                          max: 50,
                          divisions: 50, // 1% increments
                          onChanged: (value) {
                            billData.setAlcoholTipPercentage(value);
                            // Light feedback on drag
                            if (value.toInt() % 5 == 0) {
                              HapticFeedback.selectionClick();
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 16),

              // Quick tip percentage buttons for alcohol
              _buildQuickTipButtons(),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildQuickTipButtons() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children:
          [18, 20, 22, 25, 30].map((percentage) {
            return GestureDetector(
              onTap: () {
                billData.setAlcoholTipPercentage(percentage.toDouble());
                HapticFeedback.selectionClick();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color:
                      billData.alcoholTipPercentage == percentage
                          ? colorScheme.tertiary
                          : colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color:
                        billData.alcoholTipPercentage == percentage
                            ? colorScheme.tertiary
                            : colorScheme.outline.withOpacity(0.5),
                    width: 1.5,
                  ),
                  boxShadow:
                      billData.alcoholTipPercentage == percentage
                          ? [
                            BoxShadow(
                              color: colorScheme.tertiary.withOpacity(0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ]
                          : null,
                ),
                child: Text(
                  '$percentage%',
                  style: TextStyle(
                    color:
                        billData.alcoholTipPercentage == percentage
                            ? Colors.white
                            : colorScheme.onSurface,
                    fontWeight:
                        billData.alcoholTipPercentage == percentage
                            ? FontWeight.bold
                            : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
    );
  }
}
