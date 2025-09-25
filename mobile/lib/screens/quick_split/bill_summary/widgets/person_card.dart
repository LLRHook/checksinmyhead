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

import 'package:checks_frontend/screens/quick_split/bill_summary/models/bill_summary_data.dart';
import 'package:checks_frontend/screens/quick_split/bill_summary/utils/calculation_utils.dart';
import 'package:checks_frontend/screens/quick_split/item_assignment/utils/color_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '/models/person.dart';
import '/models/bill_item.dart';

/// PersonCard - Displays an individual's payment details with expandable item breakdown
///
/// Shows a person's total share, assigned items, and tax/tip contribution in an
/// interactive card with collapsible sections. Special styling for birthday person.
class PersonCard extends StatefulWidget {
  final Person person;
  final BillSummaryData data;
  final bool initiallyExpanded;

  const PersonCard({
    super.key,
    required this.person,
    required this.data,
    this.initiallyExpanded = false,
  });

  @override
  State<PersonCard> createState() => _PersonCardState();
}

class _PersonCardState extends State<PersonCard>
    with SingleTickerProviderStateMixin {
  late bool _isExpanded;
  late AnimationController _controller;
  late Animation<double> _iconTurns;

  // Animation curves for smooth transitions
  static final Animatable<double> _easeInTween = CurveTween(
    curve: Curves.easeIn,
  );
  static final Animatable<double> _halfTween = Tween<double>(
    begin: 0.0,
    end: 0.5,
  );

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;

    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _iconTurns = _controller.drive(_halfTween.chain(_easeInTween));

    if (_isExpanded) {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Toggles the expanded state with animation
  void _toggleExpanded() {
    // Provide haptic feedback for card interaction
    HapticFeedback.lightImpact();

    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final isBirthdayPerson = widget.data.birthdayPerson == widget.person;

    // Find items assigned to this person
    final personItems =
        widget.data.items
            .where((item) => (item.assignments[widget.person] ?? 0) > 0)
            .toList();

    // Get person's calculated amounts (subtotal, tax, tip, total)
    final personAmounts = CalculationUtils.calculatePersonAmounts(
      person: widget.person,
      participants: widget.data.participants,
      personShares: widget.data.personShares,
      items: widget.data.items,
      subtotal: widget.data.subtotal,
      tax: widget.data.tax,
      tipAmount: widget.data.tipAmount,
      birthdayPerson: widget.data.birthdayPerson,
    );

    final double totalShare = personAmounts['total'] ?? 0.0;

    // Theme-aware colors
    final cardBgColor =
        brightness == Brightness.dark ? colorScheme.surface : Colors.white;

    final cardShadowColor =
        brightness == Brightness.dark
            ? Colors.black.withValues(alpha: 0.2)
            : Colors.black.withValues(alpha: 0.03);

    final expandIconColor =
        brightness == Brightness.dark
            ? Colors.grey.shade400
            : Colors.grey.shade600;

    final dividerColor =
        brightness == Brightness.dark
            ? colorScheme.outline.withValues(alpha: 0.2)
            : Colors.grey.shade200;

    // Birthday-specific colors
    final birthdayBgColor =
        brightness == Brightness.dark ? Color(0xFF4A243B) : Colors.pink.shade50;

    final birthdayTextColor =
        brightness == Brightness.dark
            ? Color(0xFFF48FB1)
            : Colors.pink.shade400;

    final birthdayPillBgColor =
        brightness == Brightness.dark
            ? Color(0xFF6A2C50).withValues(alpha: 0.6)
            : Colors.pink.shade100;

    final birthdayPillTextColor =
        brightness == Brightness.dark
            ? Color(0xFFF8BBD0)
            : Colors.pink.shade700;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: cardBgColor,
        boxShadow: [
          BoxShadow(
            color: cardShadowColor,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Interactive header with person info and total amount
          InkWell(
            onTap: totalShare > 0 ? _toggleExpanded : null,
            borderRadius: BorderRadius.circular(16),
            child: _buildPersonHeader(
              context,
              isBirthdayPerson,
              totalShare,
              birthdayBgColor,
              birthdayTextColor,
              birthdayPillBgColor,
              birthdayPillTextColor,
              expandIconColor,
            ),
          ),

          // Animated collapsible content
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child:
                _isExpanded
                    ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Items list
                        if (personItems.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                            child: Text(
                              'Items',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: colorScheme.primary,
                              ),
                            ),
                          ),

                          ...personItems.map(
                            (item) =>
                                _buildItemRow(context, item, widget.person),
                          ),

                          if (!isBirthdayPerson)
                            Divider(
                              height: 16,
                              indent: 16,
                              endIndent: 16,
                              color: dividerColor,
                            ),
                        ],

                        // Tax and tip breakdown (not shown for birthday person)
                        if (!isBirthdayPerson)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                            child: Column(
                              children: [
                                if ((personAmounts['tax'] ?? 0) > 0)
                                  _buildAmountRow(
                                    context,
                                    'Tax',
                                    (personAmounts['tax'] ?? 0),
                                    isTotal: false,
                                  ),

                                if ((personAmounts['tip'] ?? 0) > 0)
                                  _buildAmountRow(
                                    context,
                                    'Tip',
                                    (personAmounts['tip'] ?? 0),
                                    isTotal: false,
                                  ),
                              ],
                            ),
                          ),
                      ],
                    )
                    : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  /// Builds the person card header with avatar, name, and total amount
  Widget _buildPersonHeader(
    BuildContext context,
    bool isBirthdayPerson,
    double totalShare,
    Color birthdayBgColor,
    Color birthdayTextColor,
    Color birthdayPillBgColor,
    Color birthdayPillTextColor,
    Color expandIconColor,
  ) {
    final brightness = Theme.of(context).brightness;

    // Calculate color based on person's assigned color or birthday status
    final headerBgColor =
        isBirthdayPerson
            ? birthdayBgColor
            : brightness == Brightness.dark
            ? ColorUtils.getDarkenedColor(
              widget.person.color,
              0.5,
            ).withValues(alpha: 0.2)
            : widget.person.color.withValues(alpha: .1);

    final pillBgColor =
        isBirthdayPerson
            ? birthdayPillBgColor
            : brightness == Brightness.dark
            ? ColorUtils.getLightenedColor(
              widget.person.color,
              0.1,
            ).withValues(alpha: .3)
            : widget.person.color.withValues(alpha: .2);

    final pillTextColor =
        isBirthdayPerson
            ? birthdayPillTextColor
            : brightness == Brightness.dark
            ? ColorUtils.getLightenedColor(widget.person.color, 0.4)
            : ColorUtils.getDarkenedColor(widget.person.color, 0.2);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: headerBgColor,
        borderRadius:
            _isExpanded
                ? const BorderRadius.vertical(top: Radius.circular(16))
                : BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: widget.person.color,
            radius: 20,
            child: Text(
              widget.person.name[0].toUpperCase(),
              style: TextStyle(
                color: ColorUtils.getContrastiveTextColor(widget.person.color),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.person.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color:
                        brightness == Brightness.dark
                            ? isBirthdayPerson
                                ? birthdayTextColor
                                : ColorUtils.getLightenedColor(
                                  widget.person.color,
                                  0.3,
                                )
                            : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                if (isBirthdayPerson)
                  Row(
                    children: [
                      Icon(Icons.cake, size: 14, color: birthdayTextColor),
                      const SizedBox(width: 4),
                      Text(
                        'Happy Birthday!',
                        style: TextStyle(
                          fontSize: 12,
                          color: birthdayTextColor,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: pillBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '\$${totalShare.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: pillTextColor,
                  ),
                ),
              ),
              if (totalShare > 0) ...[
                const SizedBox(width: 8),
                RotationTransition(
                  turns: _iconTurns,
                  child: Icon(
                    Icons.expand_more,
                    color: expandIconColor,
                    size: 20,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// Builds a row for an item assigned to the person
  Widget _buildItemRow(BuildContext context, BillItem item, Person person) {
    final percentage = item.assignments[person] ?? 0;
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    final amount = item.price * (percentage / 100);

    final secondaryTextColor =
        brightness == Brightness.dark
            ? Colors.grey.shade400
            : Colors.grey.shade600;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              item.name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          if (percentage < 100)
            Text(
              '${percentage.toStringAsFixed(0)}% × ',
              style: TextStyle(fontSize: 12, color: secondaryTextColor),
            ),
          Text(
            '\$${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a row for displaying tax/tip amounts
  Widget _buildAmountRow(
    BuildContext context,
    String label,
    double amount, {
    bool isTotal = false,
    Color? color,
  }) {
    final brightness = Theme.of(context).brightness;

    final defaultColor =
        brightness == Brightness.dark
            ? Colors.grey.shade300
            : Colors.grey.shade800;

    final textColor = color ?? defaultColor;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 15 : 14,
              color: textColor,
            ),
          ),
          Text(
            '\$${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 15 : 14,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
