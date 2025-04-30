import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/bill_data.dart';
import '../components/section_card.dart';
import '../components/input_decoration.dart';
import '../utils/currency_formatter.dart';

class TipOptionsSection extends StatelessWidget {
  const TipOptionsSection({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final billData = Provider.of<BillData>(context);

    return SectionCard(
      title: 'Tip Options',
      icon: Icons.volunteer_activism,
      children: [
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

        // Custom tip amount field (visible when custom amount is selected)
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
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),

        // Percentage tip options (visible when percentage is selected)
        if (!billData.useCustomTipAmount) ...[
          // Tip percentage display with premium styling
          _TipPercentageSlider(
            tipPercentage: billData.tipPercentage,
            color: colorScheme.primary,
            onChanged: (value) {
              billData.setTipPercentage(value);
              // Light feedback on drag
              if (value.toInt() % 5 == 0) {
                HapticFeedback.selectionClick();
              }
            },
          ),

          const SizedBox(height: 16),

          // Quick tip percentage buttons with premium styling
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
          color: isSelected ? colorScheme.primary : Colors.transparent,
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
          [15, 18, 20, 25, 30].map((percentage) {
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
                          ? colorScheme.primary
                          : colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color:
                        tipPercentage == percentage
                            ? colorScheme.primary
                            : colorScheme.outline.withOpacity(0.5),
                    width: 1.5,
                  ),
                  boxShadow:
                      tipPercentage == percentage
                          ? [
                            BoxShadow(
                              color: colorScheme.primary.withOpacity(0.2),
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
