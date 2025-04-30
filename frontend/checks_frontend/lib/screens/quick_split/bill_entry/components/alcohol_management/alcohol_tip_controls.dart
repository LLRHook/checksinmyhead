import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/bill_data.dart';
import '../../components/input_decoration.dart';
import '../../utils/currency_formatter.dart';

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

        // Only show alcohol tip options if different tip for alcohol is enabled
        if (billData.useDifferentTipForAlcohol) ...[
          SizedBox(height: 24),

          // Title and tip toggle
          Row(
            children: [
              const Spacer(),
              // Modern toggle between percentage and custom amount
              Container(
                height: 36,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ToggleOption(
                      title: 'Percentage',
                      isSelected: !billData.useCustomAlcoholTipAmount,
                      onTap: () {
                        billData.toggleCustomAlcoholTipAmount(false);
                        HapticFeedback.selectionClick();
                      },
                    ),
                    _ToggleOption(
                      title: 'Custom',
                      isSelected: billData.useCustomAlcoholTipAmount,
                      onTap: () {
                        billData.toggleCustomAlcoholTipAmount(true);
                        HapticFeedback.selectionClick();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Custom tip amount field (visible when custom amount is selected)
          if (billData.useCustomAlcoholTipAmount)
            TextFormField(
              controller: billData.customAlcoholTipController,
              decoration: AppInputDecoration.buildInputDecoration(
                context: context,
                labelText: 'Alcohol Tip Amount',
                prefixText: '\$',
                hintText: '0.00',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [CurrencyFormatter.currencyFormatter],
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),

          // Percentage tip options (visible when percentage is selected)
          if (!billData.useCustomAlcoholTipAmount) ...[
            // Tip percentage display with premium styling
            _TipPercentageSlider(
              tipPercentage: billData.alcoholTipPercentage,
              color: colorScheme.tertiary,
              onChanged: (value) {
                billData.setAlcoholTipPercentage(value);
                // Light feedback on drag
                if (value.toInt() % 5 == 0) {
                  HapticFeedback.selectionClick();
                }
              },
            ),

            const SizedBox(height: 16),

            // Quick tip percentage buttons with premium styling
            _QuickTipPercentageButtons(
              tipPercentage: billData.alcoholTipPercentage,
              onPercentageSelected: (percentage) {
                billData.setAlcoholTipPercentage(percentage);
                HapticFeedback.selectionClick();
              },
            ),
          ],
        ],
      ],
    );
  }
}

class _ToggleOption extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _ToggleOption({
    Key? key,
    required this.title,
    required this.isSelected,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.tertiary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : colorScheme.onSurfaceVariant,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _TipPercentageSlider extends StatelessWidget {
  final double tipPercentage;
  final Color color;
  final ValueChanged<double> onChanged;

  const _TipPercentageSlider({
    Key? key,
    required this.tipPercentage,
    required this.color,
    required this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(25),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text(
            '${tipPercentage.toInt()}%',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: color,
                inactiveTrackColor: color.withOpacity(0.2),
                thumbColor: color,
                overlayColor: color.withOpacity(0.2),
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
                max: 50,
                divisions: 50, // 1% increments
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickTipPercentageButtons extends StatelessWidget {
  final double tipPercentage;
  final ValueChanged<double> onPercentageSelected;

  const _QuickTipPercentageButtons({
    Key? key,
    required this.tipPercentage,
    required this.onPercentageSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children:
          [18, 20, 22, 25, 30].map((percentage) {
            return GestureDetector(
              onTap: () => onPercentageSelected(percentage.toDouble()),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color:
                      tipPercentage == percentage
                          ? colorScheme.tertiary
                          : colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color:
                        tipPercentage == percentage
                            ? colorScheme.tertiary
                            : colorScheme.outline.withOpacity(0.5),
                    width: 1.5,
                  ),
                  boxShadow:
                      tipPercentage == percentage
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
                        tipPercentage == percentage
                            ? Colors.white
                            : colorScheme.onSurface,
                    fontWeight:
                        tipPercentage == percentage
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
