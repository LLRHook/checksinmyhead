import 'package:checks_frontend/screens/quick_split/bill_entry/components/alcohol_management/alcohol_item_list.dart';
import 'package:checks_frontend/screens/quick_split/bill_entry/components/alcohol_management/alcohol_tip_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/bill_data.dart';
import '../../components/input_decoration.dart';
import '../../utils/currency_formatter.dart';

class AlcoholManagementModal extends StatefulWidget {
  const AlcoholManagementModal({Key? key}) : super(key: key);

  @override
  State<AlcoholManagementModal> createState() => _AlcoholManagementModalState();
}

class _AlcoholManagementModalState extends State<AlcoholManagementModal>
    with SingleTickerProviderStateMixin {
  // Form key for validation
  final _formKey = GlobalKey<FormState>();

  // Scroll controller to scroll to error
  final ScrollController _scrollController = ScrollController();

  // Focus node for the alcohol tax field
  final FocusNode _alcoholTaxFocusNode = FocusNode();

  // Animation controller for entrance/exit animation
  late AnimationController _animController;
  late Animation<Offset> _slideAnimation;
  double _buttonScale = 1.0;

  // Store original alcohol settings to restore on cancel
  Map<int, bool> _originalAlcoholSettings = {};
  String _originalAlcoholTax = '';
  bool _originalUseDifferentTip = false;
  double _originalAlcoholTipPercentage = 0.0;
  bool _originalUseCustomAlcoholTipAmount = false;
  String _originalCustomAlcoholTipAmount = '';

  // Error message state
  String? _validationErrorMessage;

  @override
  void initState() {
    super.initState();

    // Initialize animation controller
    _animController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    // Use slide animation instead of fade
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1), // Start from bottom
      end: Offset.zero, // End at current position
    ).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
    );

    // Start entrance animation
    _animController.forward();

    // Save original settings when modal opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final billData = Provider.of<BillData>(context, listen: false);

      // Create a deep copy of the alcohol settings
      _originalAlcoholSettings = {};
      for (int i = 0; i < billData.items.length; i++) {
        _originalAlcoholSettings[i] = billData.items[i].isAlcohol;
      }

      _originalAlcoholTax = billData.alcoholTaxController.text;
      _originalUseDifferentTip = billData.useDifferentTipForAlcohol;
      _originalAlcoholTipPercentage = billData.alcoholTipPercentage;
      _originalUseCustomAlcoholTipAmount = billData.useCustomAlcoholTipAmount;
      _originalCustomAlcoholTipAmount =
          billData.customAlcoholTipController.text;
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _scrollController.dispose();
    _alcoholTaxFocusNode.dispose();
    super.dispose();
  }

  // Function to scroll to the alcohol tax field
  void _scrollToTaxField() {
    // Add a small delay to ensure the field error is rendered
    Future.delayed(Duration(milliseconds: 100), () {
      _scrollController.animateTo(
        0, // Scroll to top since tax field is at the top
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );

      // Request focus on the tax field
      _alcoholTaxFocusNode.requestFocus();
    });
  }

  // Helper method to scroll to items section
  void _scrollToItemsSection() {
    Future.delayed(Duration(milliseconds: 100), () {
      _scrollController.animateTo(
        300, // Approximate position to alcohol items list
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    });
  }

  // Helper method to scroll to tip section
  void _scrollToTipSection() {
    Future.delayed(Duration(milliseconds: 100), () {
      _scrollController.animateTo(
        150, // Approximate position to tip controls
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    });
  }

  // Function to restore original settings when canceling
  void _restoreOriginalSettings() {
    final billData = Provider.of<BillData>(context, listen: false);

    // Restore item alcohol settings
    for (int i = 0; i < billData.items.length; i++) {
      if (i < billData.items.length &&
          _originalAlcoholSettings.containsKey(i)) {
        billData.toggleItemAlcohol(i, _originalAlcoholSettings[i]!);
      }
    }

    // Restore other settings
    billData.alcoholTaxController.text = _originalAlcoholTax;
    billData.toggleDifferentTipForAlcohol(_originalUseDifferentTip);
    billData.setAlcoholTipPercentage(_originalAlcoholTipPercentage);

    // Restore custom alcohol tip settings
    billData.toggleCustomAlcoholTipAmount(_originalUseCustomAlcoholTipAmount);
    billData.customAlcoholTipController.text = _originalCustomAlcoholTipAmount;

    // Recalculate bill with original settings
    billData.calculateBill();
  }

  // Close modal with animation and optional restore
  void _closeModal({bool shouldRestore = false}) {
    if (shouldRestore) {
      _restoreOriginalSettings();
    }

    _animController.reverse().then((_) {
      Navigator.pop(context);
    });
  }

  // Enhanced validation function for alcohol settings consistency
  bool _validateAlcoholSettings(BillData billData) {
    // Reset error message
    setState(() {
      _validationErrorMessage = null;
    });

    bool hasAlcoholItems = billData.items.any((item) => item.isAlcohol);
    bool hasTaxAmount =
        billData.alcoholTaxController.text.isNotEmpty &&
        double.tryParse(billData.alcoholTaxController.text) != null &&
        double.tryParse(billData.alcoholTaxController.text)! > 0;

    // Run the validation checks
    if (hasAlcoholItems && !hasTaxAmount) {
      // Has alcoholic items but no tax amount
      setState(() {
        _validationErrorMessage = 'Please enter the alcohol tax amount.';
      });
      _scrollToTaxField();
      return false;
    }

    if (!hasAlcoholItems && hasTaxAmount) {
      // Has tax amount but no alcoholic items
      setState(() {
        _validationErrorMessage = 'Please mark at least one item as alcoholic.';
      });
      _scrollToItemsSection();
      return false;
    }

    if (billData.useDifferentTipForAlcohol && !hasAlcoholItems) {
      // Has different tip enabled but no alcoholic items
      setState(() {
        _validationErrorMessage = 'Please mark at least one alcoholic item.';
      });
      _scrollToItemsSection();
      return false;
    }

    if (billData.useDifferentTipForAlcohol &&
        billData.useCustomAlcoholTipAmount &&
        (billData.customAlcoholTipController.text.isEmpty ||
            double.tryParse(billData.customAlcoholTipController.text) == null ||
            double.tryParse(billData.customAlcoholTipController.text)! <= 0)) {
      // Custom alcohol tip is enabled but amount not entered
      setState(() {
        _validationErrorMessage = 'Please enter a custom alcohol tip amount.';
      });
      _scrollToTipSection();
      return false;
    }

    // Check if alcohol tax exceeds total tax
double alcoholTax = double.tryParse(billData.alcoholTaxController.text) ?? 0.0;
double totalTax = double.tryParse(billData.taxController.text) ?? 0.0;

if (alcoholTax > totalTax) {
  setState(() {
    _validationErrorMessage = 'Alcohol tax cannot exceed the total tax amount.';
  });
  _scrollToTaxField();
  return false;
}

    // If all conditions are met, return true
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final billData = Provider.of<BillData>(context);
    final colorScheme = Theme.of(context).colorScheme;
    final screenHeight = MediaQuery.of(context).size.height;

    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        height: screenHeight * 0.8,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(colorScheme),

              // Modal content
              Expanded(
                child: ListView(
                  controller: _scrollController,
                  padding: EdgeInsets.all(20),
                  children: [
                    // Alcohol tax input
                    _buildTaxInputSection(context, billData),

                    // Global validation error message
                    if (_validationErrorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline, color: Colors.red),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _validationErrorMessage!,
                                  style: TextStyle(
                                    color: Colors.red.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    SizedBox(height: 24),

                    // Enable alcohol tip toggle and controls
                    AlcoholTipControls(
                      billData: billData,
                      colorScheme: colorScheme,
                    ),

                    SizedBox(height: 24),

                    // Mark alcoholic items section
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mark Alcoholic Items',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Tap to select items that are alcoholic beverages',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 12),

                        AlcoholItemList(
                          billData: billData,
                          onItemToggled: (hasAnyAlcoholicItems) {
                            // Clear error when user takes action to fix the issue
                            if (hasAnyAlcoholicItems &&
                                _validationErrorMessage != null) {
                              setState(() {
                                _validationErrorMessage = null;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              _buildSaveButton(billData, colorScheme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.tertiaryContainer,
            colorScheme.tertiaryContainer.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Icon(
            Icons.wine_bar_outlined,
            color: colorScheme.onTertiaryContainer,
            size: 24,
          ),
          SizedBox(width: 12),
          Text(
            'Manage Alcohol Items',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colorScheme.onTertiaryContainer,
            ),
          ),
          Spacer(),
          IconButton(
            icon: Icon(Icons.close, color: colorScheme.onTertiaryContainer),
            onPressed: () {
              // Close and restore original settings
              _closeModal(shouldRestore: true);
              HapticFeedback.mediumImpact();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTaxInputSection(BuildContext context, BillData billData) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Alcohol Tax',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        SizedBox(height: 8),
        TextFormField(
          controller: billData.alcoholTaxController,
          focusNode: _alcoholTaxFocusNode,
          decoration: AppInputDecoration.buildInputDecoration(
            context: context,
            labelText: 'Alcohol Tax Amount',
            prefixText: '\$',
            hintText: '0.00',
            prefixIcon: Icons.receipt_long,
          ),
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [CurrencyFormatter.currencyFormatter],
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          onChanged: (value) {
            // Clear error when user takes action to fix the issue
            if (value.isNotEmpty && _validationErrorMessage != null) {
              setState(() {
                _validationErrorMessage = null;
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildSaveButton(BillData billData, ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: AnimatedScale(
        scale: _buttonScale,
        duration: const Duration(milliseconds: 100),
        child: ElevatedButton(
          onPressed: () {
            // Create a temporary ripple scale effect
            setState(() {
              _buttonScale = 0.97;
            });

            Future.delayed(Duration(milliseconds: 100), () {
              if (mounted) {
                setState(() {
                  _buttonScale = 1.0;
                });
              }
            });

            // Use our custom validation logic
            bool isValid = _validateAlcoholSettings(billData);

            if (!isValid) {
              // Show error feedback
              HapticFeedback.vibrate();
              return;
            }

            // If validation passed, proceed
            // Recalculate bill before closing
            billData.calculateBill();

            // Provide haptic feedback
            HapticFeedback.mediumImpact();

            // Close the modal with animation (no restore needed since we're saving)
            _closeModal(shouldRestore: false);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.tertiary,
            foregroundColor: Colors.white,
            elevation: 2,
            padding: EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Text(
            'Save & Apply',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
