import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '/models/person.dart';
import '/models/bill_item.dart';
import 'dart:math' as math;

class BillSummaryScreen extends StatefulWidget {
  final List<Person> participants;
  final Map<Person, double> personShares;
  final List<BillItem> items;
  final double subtotal;
  final double tax;
  final double tipAmount;
  final double total;
  final Person? birthdayPerson;

  const BillSummaryScreen({
    super.key,
    required this.participants,
    required this.personShares,
    required this.items,
    required this.subtotal,
    required this.tax,
    required this.tipAmount,
    required this.total,
    this.birthdayPerson,
  });

  @override
  State<BillSummaryScreen> createState() => _BillSummaryScreenState();
}

class _BillSummaryScreenState extends State<BillSummaryScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final PageController _pageController = PageController();
  int _currentPersonIndex = 0;
  bool _isShareExpanded = false;
  double _animatedTotal = 0.0;

  // Animation controller for entrance animations
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // For confetti effect on success
  final List<_ConfettiParticle> _confetti = [];
  bool _showConfetti = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Animation configuration
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    // Animate total amount counter
    Future.delayed(const Duration(milliseconds: 300), () {
      _animateTotal();
    });

    // Start animations
    _animationController.forward();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _animateTotal() {
    const duration = Duration(milliseconds: 1500);
    final totalAmount = widget.total;

    setState(() {
      _animatedTotal = 0;
    });

    int steps = 100;
    double increment = totalAmount / steps;
    int stepDuration = duration.inMilliseconds ~/ steps;

    for (int i = 1; i <= steps; i++) {
      Future.delayed(Duration(milliseconds: stepDuration * i), () {
        if (mounted) {
          setState(() {
            _animatedTotal = i * increment;
            if (i == steps) {
              _animatedTotal = totalAmount; // Ensure exact final value
            }
          });
        }
      });
    }
  }

  void _showSuccessDialog() {
    // Trigger confetti effect
    setState(() {
      _showConfetti = true;
      _generateConfetti();
    });

    // Provide haptic feedback for success
    HapticFeedback.mediumImpact();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            contentPadding: const EdgeInsets.all(24),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle_outline,
                    color: Colors.green.shade600,
                    size: 64,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Success!',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your bill has been successfully saved.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 12,
                    ),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  // Generate confetti particles for success animation
  void _generateConfetti() {
    _confetti.clear();
    final random = math.Random();
    for (int i = 0; i < 100; i++) {
      _confetti.add(
        _ConfettiParticle(
          position: Offset(
            random.nextDouble() * MediaQuery.of(context).size.width,
            -10 - random.nextDouble() * 20,
          ),
          color: Color.fromRGBO(
            100 + random.nextInt(155),
            100 + random.nextInt(155),
            100 + random.nextInt(155),
            1,
          ),
          size: 5 + random.nextDouble() * 8,
          velocity: Offset(
            (random.nextDouble() - 0.5) * 3,
            3 + random.nextDouble() * 4,
          ),
          rotationSpeed: (random.nextDouble() - 0.5) * 0.1,
          angle: random.nextDouble() * math.pi * 2,
        ),
      );
    }

    _animateConfetti();
  }

  void _animateConfetti() {
    if (!_showConfetti) return;

    setState(() {
      for (var particle in _confetti) {
        particle.position += particle.velocity;
        particle.angle += particle.rotationSpeed;

        // Apply gravity
        particle.velocity += const Offset(0, 0.1);

        // Add slight randomness to movement
        final random = math.Random();
        particle.velocity += Offset((random.nextDouble() - 0.5) * 0.3, 0);
      }
    });

    // Remove particles that are off-screen
    _confetti.removeWhere(
      (particle) =>
          particle.position.dy > MediaQuery.of(context).size.height + 50,
    );

    if (_confetti.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 16), _animateConfetti);
    } else {
      setState(() {
        _showConfetti = false;
      });
    }
  }

  // Calculate individual person's amounts
  Map<String, double> _calculatePersonAmounts(Person person) {
    double subtotal = 0.0;

    // Calculate person's subtotal from items
    for (var item in widget.items) {
      subtotal += item.amountForPerson(person);
    }

    // If no items were entered, calculate from final share
    if (widget.items.isEmpty) {
      // Estimate subtotal portion from total share
      final double totalShare = widget.personShares[person] ?? 0.0;
      final double taxAndTipPercentage =
          (widget.tax + widget.tipAmount) / widget.subtotal;
      subtotal = totalShare / (1 + taxAndTipPercentage);
    }

    // Calculate tax and tip proportionally
    final double proportion = subtotal / widget.subtotal;
    final double tax = widget.tax * proportion;
    final double tip = widget.tipAmount * proportion;

    return {
      'subtotal': subtotal,
      'tax': tax,
      'tip': tip,
      'total': subtotal + tax + tip,
    };
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Sort participants by amount (highest to lowest)
    final sortedParticipants = List<Person>.from(widget.participants);
    sortedParticipants.sort((a, b) {
      final aAmount = widget.personShares[a] ?? 0;
      final bAmount = widget.personShares[b] ?? 0;
      return bAmount.compareTo(aAmount);
    });

    return Scaffold(
      backgroundColor: colorScheme.surface,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Bill Summary',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text(
                    'Tax and tip are split proportionally based on each person\'s subtotal',
                  ),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  margin: const EdgeInsets.all(16),
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  colorScheme.primaryContainer.withOpacity(0.3),
                  colorScheme.surface,
                  colorScheme.surface,
                ],
                stops: const [0.0, 0.3, 1.0],
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Column(
                  children: [
                    // Bill header card with animated total
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: _buildBillHeaderCard(colorScheme),
                    ),

                    // Tab bar for switching between views
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: TabBar(
                            controller: _tabController,
                            indicator: BoxDecoration(
                              color: colorScheme.primary,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            labelColor: Colors.white,
                            unselectedLabelColor: Colors.grey.shade700,
                            tabs: const [
                              Tab(text: 'Individual'),
                              Tab(text: 'Overview'),
                            ],
                            onTap: (index) {
                              HapticFeedback.selectionClick();
                            },
                          ),
                        ),
                      ),
                    ),

                    // Tab content
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          // Individual tab
                          _buildIndividualTab(
                            sortedParticipants,
                            colorScheme,
                            textTheme,
                          ),

                          // Overview tab
                          _buildOverviewTab(
                            sortedParticipants,
                            colorScheme,
                            textTheme,
                          ),
                        ],
                      ),
                    ),

                    // Bottom actions
                    _buildBottomActions(colorScheme),
                  ],
                ),
              ),
            ),
          ),

          // Confetti overlay
          if (_showConfetti)
            CustomPaint(
              painter: _ConfettiPainter(particles: _confetti),
              size: Size.infinite,
            ),
        ],
      ),
    );
  }

  Widget _buildBillHeaderCard(ColorScheme colorScheme) {
    return Card(
      elevation: 2,
      shadowColor: colorScheme.primary.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long, color: colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'BILL TOTAL',
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Animated total amount
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: 0.8 + (0.2 * value),
                  child: Opacity(
                    opacity: value,
                    child: Text(
                      '\$${_animatedTotal.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                );
              },
            ),

            // Bill breakdown
            const SizedBox(height: 16),
            _billBreakdownRow('Subtotal', widget.subtotal),
            const SizedBox(height: 4),
            _billBreakdownRow('Tax', widget.tax),
            const SizedBox(height: 4),
            _billBreakdownRow('Tip', widget.tipAmount),
          ],
        ),
      ),
    );
  }

  Widget _billBreakdownRow(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
          Text(
            '\$${amount.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildIndividualTab(
    List<Person> sortedParticipants,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    // Show person cards in a PageView
    return Column(
      children: [
        // Person indicator dots
        if (sortedParticipants.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildPersonIndicator(sortedParticipants, colorScheme),
          ),

        // Person card pager
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: sortedParticipants.length,
            onPageChanged: (index) {
              setState(() {
                _currentPersonIndex = index;
              });
              // Provide haptic feedback when changing pages
              HapticFeedback.selectionClick();
            },
            itemBuilder: (context, index) {
              final person = sortedParticipants[index];
              final isBirthdayPerson = widget.birthdayPerson == person;
              final personAmounts = _calculatePersonAmounts(person);

              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Card(
                  elevation: 1,
                  shadowColor: Colors.black.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                    side: BorderSide(
                      color:
                          isBirthdayPerson
                              ? Colors.pink.shade200
                              : person.color.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      decoration: BoxDecoration(
                        // Add gradient background
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            isBirthdayPerson
                                ? Colors.pink.shade50
                                : person.color.withOpacity(0.05),
                            Colors.white,
                          ],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Person header
                          _buildPersonHeader(
                            person,
                            isBirthdayPerson,
                            colorScheme,
                          ),

                          // Items list
                          Expanded(
                            child: _buildPersonItems(
                              person,
                              personAmounts,
                              isBirthdayPerson,
                              colorScheme,
                            ),
                          ),

                          // Total amount card at bottom
                          _buildPersonTotalCard(
                            person,
                            personAmounts,
                            isBirthdayPerson,
                            colorScheme,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPersonIndicator(
    List<Person> participants,
    ColorScheme colorScheme,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(participants.length, (index) {
        final isSelected = index == _currentPersonIndex;

        return GestureDetector(
          onTap: () {
            _pageController.animateToPage(
              index,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            height: 8,
            width: isSelected ? 24 : 8,
            decoration: BoxDecoration(
              color:
                  isSelected ? participants[index].color : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildPersonHeader(
    Person person,
    bool isBirthdayPerson,
    ColorScheme colorScheme,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Row(
        children: [
          // Person avatar with animated border
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 1500),
            curve: Curves.elasticOut,
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient:
                        isBirthdayPerson
                            ? LinearGradient(
                              colors: [
                                Colors.pink.shade300,
                                Colors.purple.shade300,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                            : LinearGradient(
                              colors: [
                                person.color,
                                Color.lerp(person.color, Colors.white, 0.5) ??
                                    person.color,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                  ),
                  child: CircleAvatar(
                    backgroundColor: person.color,
                    radius: 24,
                    child: Text(
                      person.name[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(width: 16),

          // Person name and tags
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  person.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                if (isBirthdayPerson) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.pink.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.cake,
                              size: 12,
                              color: Colors.pink.shade700,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Birthday Person',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.pink.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Share amount
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${(widget.personShares[person] ?? 0).toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color:
                      isBirthdayPerson
                          ? Colors.pink.shade700
                          : colorScheme.primary,
                ),
              ),
              Text(
                isBirthdayPerson ? 'Free!' : 'to pay',
                style: TextStyle(
                  fontSize: 12,
                  color:
                      isBirthdayPerson
                          ? Colors.pink.shade700
                          : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPersonItems(
    Person person,
    Map<String, double> personAmounts,
    bool isBirthdayPerson,
    ColorScheme colorScheme,
  ) {
    final items =
        widget.items
            .where((item) => (item.assignments[person] ?? 0) > 0)
            .toList();

    if (items.isEmpty) {
      // Show placeholder for no items
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No specific items',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              isBirthdayPerson
                  ? 'Lucky you! Your share is covered.'
                  : 'Bill was split evenly',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final percentage = item.assignments[person] ?? 0;
        final itemAmount = item.price * (percentage / 100);

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 6,
            ),
            leading: CircleAvatar(
              backgroundColor: person.color.withOpacity(0.1),
              child: Icon(Icons.restaurant_menu, color: person.color, size: 18),
            ),
            title: Text(
              item.name,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            subtitle:
                percentage != 100
                    ? Text(
                      '${percentage.toStringAsFixed(0)}% of \$${item.price.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    )
                    : null,
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: person.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '\$${itemAmount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: person.color,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPersonTotalCard(
    Person person,
    Map<String, double> personAmounts,
    bool isBirthdayPerson,
    ColorScheme colorScheme,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Card(
        elevation: 0,
        color:
            isBirthdayPerson
                ? Colors.pink.shade50
                : colorScheme.primary.withOpacity(0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color:
                isBirthdayPerson
                    ? Colors.pink.shade200
                    : colorScheme.primary.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Subtotal',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    '\$${personAmounts['subtotal']?.toStringAsFixed(2) ?? '0.00'}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Tax + Tip',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  Text(
                    '\$${(personAmounts['tax']! + personAmounts['tip']!).toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              const Divider(height: 16, thickness: 1),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'TOTAL',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color:
                          isBirthdayPerson
                              ? Colors.pink.shade700
                              : colorScheme.primary,
                    ),
                  ),
                  Text(
                    '\$${personAmounts['total']?.toStringAsFixed(2) ?? '0.00'}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color:
                          isBirthdayPerson
                              ? Colors.pink.shade700
                              : colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewTab(
    List<Person> sortedParticipants,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Split breakdown visualization
          _buildSplitVisualization(sortedParticipants, colorScheme),

          const SizedBox(height: 24),

          // All participants summary
          Text(
            'All Participants',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // Participant cards
          ...sortedParticipants.map(
            (person) => _buildParticipantSummaryCard(person, colorScheme),
          ),

          const SizedBox(height: 24),

          // Items summary
          if (widget.items.isNotEmpty) ...[
            Text(
              'Items Summary',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.shade200, width: 1),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    ...widget.items.map(
                      (item) => _buildItemSummaryRow(item, colorScheme),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSplitVisualization(
    List<Person> participants,
    ColorScheme colorScheme,
  ) {
    final List<Widget> sections = [];
    double cumulativePercentage = 0;

    // Calculate total for percentage
    final double total = widget.total > 0 ? widget.total : 1;

    for (int i = 0; i < participants.length; i++) {
      final person = participants[i];
      final share = widget.personShares[person] ?? 0;
      final percentage = (share / total) * 100;

      // Skip if percentage is too small to render
      if (percentage < 0.5) continue;

      // Use fractional values of 1.0 instead of percentages
      final leftFraction = cumulativePercentage / 100;
      final widthFraction = percentage / 100;

      sections.add(
        Positioned(
          left: leftFraction * 100, // Convert to absolute position
          width: widthFraction * 100, // Convert to absolute width
          top: 0,
          bottom: 0,
          child: Container(
            decoration: BoxDecoration(
              color: person.color.withOpacity(0.7),
              border:
                  i == 0
                      ? Border.all(width: 0, color: Colors.transparent)
                      : Border(left: BorderSide(color: Colors.white, width: 2)),
            ),
          ),
        ),
      );

      // Add label if section is wide enough
      if (percentage > 10) {
        // Calculate center position
        final centerPosition = (cumulativePercentage + (percentage / 2)) / 100;

        sections.add(
          Positioned(
            left:
                (centerPosition * 100) - 20, // Center the label, adjust by 20px
            top: 0,
            bottom: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${percentage.toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: person.color,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        );
      }

      cumulativePercentage += percentage;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Split Distribution',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          height: 40,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(children: sections),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              participants.map((person) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: person.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: person.color.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: person.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        person.name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
        ),
      ],
    );
  }

  Widget _buildParticipantSummaryCard(Person person, ColorScheme colorScheme) {
    final share = widget.personShares[person] ?? 0;
    final isBirthdayPerson = widget.birthdayPerson == person;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: person.color.withOpacity(0.3), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: person.color,
              radius: 16,
              child: Text(
                person.name[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    person.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  if (isBirthdayPerson)
                    Row(
                      children: [
                        Icon(Icons.cake, size: 12, color: Colors.pink.shade400),
                        const SizedBox(width: 4),
                        Text(
                          'Birthday Person',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.pink.shade400,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color:
                    isBirthdayPerson
                        ? Colors.pink.shade50
                        : person.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '\${share.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isBirthdayPerson ? Colors.pink.shade700 : person.color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemSummaryRow(BillItem item, ColorScheme colorScheme) {
    // Get all people assigned to this item
    final assignedPeople =
        widget.participants
            .where((person) => (item.assignments[person] ?? 0) > 0)
            .toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.restaurant_menu,
              color: colorScheme.primary,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children:
                      assignedPeople.map((person) {
                        final percentage = item.assignments[person] ?? 0;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: person.color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${person.name} (${percentage.toStringAsFixed(0)}%)',
                            style: TextStyle(
                              fontSize: 11,
                              color: person.color,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '\${item.price.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions(ColorScheme colorScheme) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: _isShareExpanded ? null : 0,
              child: Opacity(
                opacity: _isShareExpanded ? 1.0 : 0.0,
                child:
                    _isShareExpanded
                        ? Column(
                          children: [
                            Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: colorScheme.primary.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: colorScheme.primary.withOpacity(0.2),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      _buildShareButton(
                                        Icons.message,
                                        'Text',
                                        colorScheme.primary,
                                      ),
                                      _buildShareButton(
                                        Icons.email,
                                        'Email',
                                        Colors.blue.shade700,
                                      ),
                                      _buildShareButton(
                                        Icons.copy,
                                        'Copy',
                                        Colors.purple.shade700,
                                      ),
                                      _buildShareButton(
                                        Icons.more_horiz,
                                        'More',
                                        Colors.grey.shade700,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                        : const SizedBox(),
              ),
            ),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Toggle share options
                      setState(() {
                        _isShareExpanded = !_isShareExpanded;
                      });
                      HapticFeedback.selectionClick();
                    },
                    icon: Icon(
                      _isShareExpanded ? Icons.close : Icons.share,
                      size: 18,
                    ),
                    label: Text(_isShareExpanded ? 'Cancel' : 'Share'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _isShareExpanded
                              ? Colors.grey.shade200
                              : colorScheme.primaryContainer,
                      foregroundColor:
                          _isShareExpanded
                              ? Colors.grey.shade800
                              : colorScheme.onPrimaryContainer,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _showSuccessDialog,
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('Done'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 2,
                      shadowColor: colorScheme.primary.withOpacity(0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShareButton(IconData icon, String label, Color color) {
    return InkWell(
      onTap: () {
        // Show toast for sharing functionality
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sharing via $label will be available soon!'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );

        // Collapse share options
        setState(() {
          _isShareExpanded = false;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Confetti particle class for success animation
class _ConfettiParticle {
  Offset position;
  final Color color;
  final double size;
  Offset velocity;
  double angle;
  final double rotationSpeed;

  _ConfettiParticle({
    required this.position,
    required this.color,
    required this.size,
    required this.velocity,
    required this.angle,
    required this.rotationSpeed,
  });
}

// Confetti painter
class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;

  _ConfettiPainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    for (var particle in particles) {
      paint.color = particle.color;

      canvas.save();
      canvas.translate(particle.position.dx, particle.position.dy);
      canvas.rotate(particle.angle);

      // Draw a rectangle for confetti
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: particle.size,
          height: particle.size * 1.5,
        ),
        paint,
      );

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
