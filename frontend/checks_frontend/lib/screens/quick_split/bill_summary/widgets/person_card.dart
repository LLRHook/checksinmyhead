import 'package:checks_frontend/screens/quick_split/item_assignment/utils/color_utils.dart';
import 'package:flutter/material.dart';
import '../models/bill_summary_data.dart';
import '../utils/calculation_utils.dart';
import '/models/person.dart';
import '/models/bill_item.dart';

class PersonCard extends StatefulWidget {
  final Person person;
  final BillSummaryData data;
  final bool initiallyExpanded;

  const PersonCard({
    Key? key,
    required this.person,
    required this.data,
    this.initiallyExpanded = false,
  }) : super(key: key);

  @override
  State<PersonCard> createState() => _PersonCardState();
}

class _PersonCardState extends State<PersonCard>
    with SingleTickerProviderStateMixin {
  late bool _isExpanded;
  late AnimationController _controller;
  late Animation<double> _iconTurns;

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

  void _toggleExpanded() {
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

    // Get items assigned to this person
    final personItems =
        widget.data.items
            .where((item) => (item.assignments[widget.person] ?? 0) > 0)
            .toList();

    // Calculate person's base amounts from CalculationUtils
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

    // Calculate total share
    final double totalShare = personAmounts['total'] ?? 0.0;

    // Theme-aware colors
    final cardBgColor =
        brightness == Brightness.dark ? colorScheme.surface : Colors.white;

    final cardShadowColor =
        brightness == Brightness.dark
            ? Colors.black.withOpacity(0.2)
            : Colors.black.withOpacity(0.03);

    final expandIconColor =
        brightness == Brightness.dark
            ? Colors.grey.shade400
            : Colors.grey.shade600;

    final dividerColor =
        brightness == Brightness.dark
            ? colorScheme.outline.withOpacity(0.2)
            : Colors.grey.shade200;

    // Birthday colors - enhanced for dark mode
    final birthdayBgColor =
        brightness == Brightness.dark
            ? Color(0xFF4A243B) // Darker pink for dark mode
            : Colors.pink.shade50;

    final birthdayTextColor =
        brightness == Brightness.dark
            ? Color(0xFFF48FB1) // Lighter pink for dark mode text
            : Colors.pink.shade400;

    final birthdayPillBgColor =
        brightness == Brightness.dark
            ? Color(0xFF6A2C50).withOpacity(
              0.6,
            ) // Darker pink for pill in dark mode
            : Colors.pink.shade100;

    final birthdayPillTextColor =
        brightness == Brightness.dark
            ? Color(0xFFF8BBD0) // Very light pink for text in pill
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
          // Person header with total - now clickable
          InkWell(
            onTap: _toggleExpanded,
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

          // Collapsible content with animation
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child:
                _isExpanded
                    ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Items list (if any)
                        if (personItems.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                            child: Text(
                              'Items',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),

                          ...personItems.map(
                            (item) =>
                                _buildItemRow(context, item, widget.person),
                          ),

                          if (!isBirthdayPerson) // Only add divider if not birthday person
                            Divider(
                              height: 16,
                              indent: 16,
                              endIndent: 16,
                              color: dividerColor,
                            ),
                        ],

                        // Tax and tip details - only for non-birthday people
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

                                // Only show tip if amount > 0
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

    // Calculate header background color based on person's color
    final headerBgColor =
        isBirthdayPerson
            ? birthdayBgColor
            : brightness == Brightness.dark
            ? ColorUtils.getDarkenedColor(
              widget.person.color,
              0.5,
            ).withOpacity(0.2)
            : widget.person.color.withOpacity(0.1);

    // Calculate pill background and text colors
    final pillBgColor =
        isBirthdayPerson
            ? birthdayPillBgColor
            : brightness == Brightness.dark
            ? ColorUtils.getLightenedColor(
              widget.person.color,
              0.1,
            ).withOpacity(0.3)
            : widget.person.color.withOpacity(0.2);

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
                            : brightness == Brightness.dark
                            ? Theme.of(context).colorScheme.onSurface
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
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(BuildContext context, BillItem item, Person person) {
    final percentage = item.assignments[person] ?? 0;
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    // Calculate amount from the item price
    final amount = item.price * (percentage / 100);

    // Theme-aware colors
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

  Widget _buildAmountRow(
    BuildContext context,
    String label,
    double amount, {
    bool isTotal = false,
    Color? color,
  }) {
    final brightness = Theme.of(context).brightness;

    // Theme-aware default text color if not specified
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
