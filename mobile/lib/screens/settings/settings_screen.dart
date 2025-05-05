// SettingsScreen manages user payment preferences, allowing setup during onboarding
// or configuration through the settings menu. Users can add, edit, or remove payment
// methods that friends can use to send them money.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

class SettingsScreen extends StatefulWidget {
  // Controls whether shown during onboarding or as settings page
  final bool isOnboarding;

  const SettingsScreen({super.key, this.isOnboarding = false});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Available payment methods
  final List<String> _paymentOptions = [
    'Venmo',
    'Zelle',
    'Apple Pay',
    'PayPal',
    'Cash App',
  ];

  // Stores user identifiers for each payment method
  final Map<String, String> _paymentIdentifiers = {};

  // Input field hints for different payment methods
  final Map<String, String> _paymentHints = {
    'Venmo': '@username',
    'PayPal': 'PayPal email/username',
    'Cash App': '\$cashtag',
    'Zelle': 'Zelle phone number/email',
    'Apple Pay': 'Phone number',
  };

  // Currently selected payment methods
  List<String> _selectedPayments = [];

  @override
  void initState() {
    super.initState();
    _loadPaymentSettings();

    // Auto-show payment selection during onboarding
    if (widget.isOnboarding) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showPaymentSelection();
      });
    }
  }

  // Load saved payment preferences
  Future<void> _loadPaymentSettings() async {
    final prefs = await SharedPreferences.getInstance();

    final savedPayments = prefs.getStringList('selectedPayments') ?? [];

    final Map<String, String> savedIdentifiers = {};
    for (final method in _paymentOptions) {
      final identifier = prefs.getString('payment_$method');
      if (identifier != null && identifier.isNotEmpty) {
        savedIdentifiers[method] = identifier;
      }
    }

    setState(() {
      _selectedPayments = savedPayments;
      _paymentIdentifiers.addAll(savedIdentifiers);
    });
  }

  // Persist payment preferences
  Future<void> _savePaymentSettings() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setStringList('selectedPayments', _selectedPayments);

    for (final entry in _paymentIdentifiers.entries) {
      await prefs.setString('payment_${entry.key}', entry.value);
    }

    // Mark onboarding as complete if applicable
    if (widget.isOnboarding) {
      await prefs.setBool('is_first_launch', false);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment settings saved'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      HapticFeedback.selectionClick();
    }
  }

  // Show bottom sheet for configuring payment methods
  void _showPaymentSelection() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      isDismissible: !widget.isOnboarding,
      enableDrag: !widget.isOnboarding,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 20,
                  horizontal: 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Text(
                        'Set Up Payment Methods',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    widget.isOnboarding
                        ? const Padding(
                          padding: EdgeInsets.only(bottom: 16),
                          child: Text(
                            'Add your payment info to help friends send you money when splitting bills.',
                            style: TextStyle(fontSize: 14),
                          ),
                        )
                        : const SizedBox.shrink(),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _paymentOptions.length,
                        itemBuilder: (context, index) {
                          final option = _paymentOptions[index];
                          final isSelected = _selectedPayments.contains(option);
                          final hasIdentifier =
                              _paymentIdentifiers.containsKey(option) &&
                              _paymentIdentifiers[option]!.isNotEmpty;

                          return Column(
                            children: [
                              ListTile(
                                title: Text(option),
                                subtitle:
                                    hasIdentifier
                                        ? Text(
                                          _paymentIdentifiers[option] ?? '',
                                        )
                                        : null,
                                trailing:
                                    isSelected
                                        ? Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(
                                                Icons.edit,
                                                color: Color(0xFF627D98),
                                              ),
                                              onPressed: () {
                                                _showIdentifierInput(
                                                  option,
                                                  setModalState,
                                                );
                                              },
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.delete,
                                                color: Colors.redAccent,
                                              ),
                                              onPressed: () {
                                                setModalState(() {
                                                  _selectedPayments.remove(
                                                    option,
                                                  );
                                                  _paymentIdentifiers.remove(
                                                    option,
                                                  );
                                                });
                                                setState(
                                                  () {},
                                                ); // Update parent state
                                              },
                                            ),
                                          ],
                                        )
                                        : null,
                                onTap: () {
                                  if (isSelected) {
                                    // Show options menu for existing method
                                    _showPaymentMethodOptions(
                                      option,
                                      setModalState,
                                    );
                                  } else {
                                    // Direct to input for new method
                                    _showIdentifierInput(option, setModalState);
                                  }
                                },
                              ),
                              if (index < _paymentOptions.length - 1)
                                const Divider(height: 1),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          _savePaymentSettings();

                          // Navigate to main screen if onboarding complete
                          if (widget.isOnboarding &&
                              _selectedPayments.isNotEmpty) {
                            Navigator.of(
                              context,
                            ).pushReplacementNamed('/landing');
                          } else {
                            Navigator.pop(context);
                          }
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).brightness == Brightness.dark
                                  ? const Color(0xFF627D98)
                                  : Colors.white,
                          foregroundColor:
                              Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white
                                  : Theme.of(context).colorScheme.primary,
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          widget.isOnboarding ? 'Continue' : 'Save',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Display action menu for an existing payment method
  void _showPaymentMethodOptions(
    String paymentMethod,
    StateSetter setModalState,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit'),
                onTap: () {
                  Navigator.pop(context);
                  _showIdentifierInput(paymentMethod, setModalState);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.redAccent),
                title: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.redAccent),
                ),
                onTap: () {
                  setModalState(() {
                    _selectedPayments.remove(paymentMethod);
                    _paymentIdentifiers.remove(paymentMethod);
                  });
                  setState(() {}); // Update parent state
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Show input field for payment identifier
  void _showIdentifierInput(String paymentMethod, StateSetter setModalState) {
    final TextEditingController controller = TextEditingController();
    controller.text = _paymentIdentifiers[paymentMethod] ?? '';

    // Select appropriate keyboard type based on payment method
    TextInputType keyboardType = TextInputType.text;

    if (paymentMethod == 'Zelle' || paymentMethod == 'Apple Pay') {
      keyboardType = TextInputType.phone;
    } else if (paymentMethod == 'PayPal' ||
        paymentMethod == 'Venmo' ||
        paymentMethod == 'Cash App') {
      keyboardType = TextInputType.emailAddress;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 20,
            left: 16,
            right: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Set Up $paymentMethod',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: keyboardType,
                autofocus: true,
                style: TextStyle(
                  color:
                      Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black,
                ),
                decoration: InputDecoration(
                  hintText: _paymentHints[paymentMethod],
                  filled: true,
                  fillColor:
                      Theme.of(context).brightness == Brightness.dark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    final value = controller.text.trim();
                    setModalState(() {
                      if (value.isNotEmpty) {
                        if (!_selectedPayments.contains(paymentMethod)) {
                          _selectedPayments.add(paymentMethod);
                        }
                        _paymentIdentifiers[paymentMethod] = value;
                      }
                    });
                    setState(() {}); // Update parent state
                    Navigator.pop(context);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF627D98)
                            : Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Save',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  // Open app store rating page
  Future<void> _openAppStore() async {
    final Uri url = Uri.parse(
      'https://apps.apple.com/app/yourappid',
    ); // TODO: Replace with actual app ID
    if (!await launchUrl(url)) {
      throw Exception('Could not launch $url');
    }
  }

  // Launch share sheet with app info
  Future<void> _shareApp() async {
    const String appStoreLink = 'https://apps.apple.com/app/yourappid';
    // TODO: Replace with actual app ID
    const String shareText =
        'Check out Checkmate, the easiest way to split bills with friends! $appStoreLink';

    const String subject = 'Try Checkmate!';

    SharePlus.instance.share(ShareParams(text: shareText, subject: subject));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colorScheme.primary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Settings',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        automaticallyImplyLeading: !widget.isOnboarding,
        actions:
            widget.isOnboarding
                ? [
                  TextButton(
                    onPressed: () {
                      // Skip payment setup and go to main screen
                      SharedPreferences.getInstance().then((prefs) {
                        prefs.setBool('is_first_launch', false);
                        Navigator.of(context).pushReplacementNamed('/landing');
                      });
                    },
                    child: const Text(
                      '',
                    ), // Empty skip button - should have text
                  ),
                ]
                : null,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // App branding section
                const Center(
                  child: Column(
                    children: [
                      Text(
                        'Checkmate',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.37,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Made by a few friends tired of using\nspreadsheets to split the bill.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // Payment methods section
                Container(
                  decoration: BoxDecoration(
                    color:
                        isDark
                            ? colorScheme.surfaceContainerHighest
                            : Colors.white.withValues(alpha: .15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Payment Options',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // "Add Payment Methods" button or list of existing methods
                      _selectedPayments.isEmpty
                          ? Padding(
                            padding: const EdgeInsets.all(16),
                            child: FilledButton(
                              onPressed: _showPaymentSelection,
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: colorScheme.primary,
                                minimumSize: const Size.fromHeight(50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Add Payment Methods',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          )
                          : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _selectedPayments.length,
                            separatorBuilder:
                                (context, index) => const Divider(
                                  color: Colors.white24,
                                  height: 1,
                                  indent: 16,
                                  endIndent: 16,
                                ),
                            itemBuilder: (context, index) {
                              final paymentMethod = _selectedPayments[index];
                              final identifier =
                                  _paymentIdentifiers[paymentMethod] ??
                                  'Not set';

                              return Dismissible(
                                key: Key(paymentMethod),
                                background: Container(
                                  color: Colors.redAccent,
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20.0),
                                  child: const Icon(
                                    Icons.delete,
                                    color: Colors.white,
                                  ),
                                ),
                                direction: DismissDirection.endToStart,
                                confirmDismiss: (direction) async {
                                  return await showDialog(
                                    context: context,
                                    builder: (BuildContext context) {
                                      return AlertDialog(
                                        title: Text('Delete $paymentMethod?'),
                                        actions: <Widget>[
                                          TextButton(
                                            onPressed:
                                                () => Navigator.of(
                                                  context,
                                                ).pop(false),
                                            child: const Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed:
                                                () => Navigator.of(
                                                  context,
                                                ).pop(true),
                                            child: const Text(
                                              'Delete',
                                              style: TextStyle(
                                                color: Colors.redAccent,
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
                                onDismissed: (direction) {
                                  setState(() {
                                    _selectedPayments.removeAt(index);
                                    _paymentIdentifiers.remove(paymentMethod);
                                  });
                                  _savePaymentSettings();
                                },
                                child: ListTile(
                                  title: Text(
                                    paymentMethod,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  subtitle: Text(
                                    identifier,
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.7,
                                      ),
                                    ),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.more_horiz,
                                          color: Colors.white70,
                                          size: 20,
                                        ),
                                        onPressed: () {
                                          _showPaymentMethodOptions(
                                            paymentMethod,
                                            (setState) {
                                              // Update state if needed
                                            },
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),

                      // "Edit Payment Methods" button for existing methods
                      if (_selectedPayments.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: OutlinedButton(
                            onPressed: _showPaymentSelection,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.white70),
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Edit Payment Methods',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Privacy information section with expandable details
                Container(
                  decoration: BoxDecoration(
                    color:
                        isDark
                            ? colorScheme.surfaceContainerHighest
                            : Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Theme(
                    data: Theme.of(
                      context,
                    ).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      title: Row(
                        children: [
                          const Icon(
                            Icons.shield_outlined,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Privacy & Data',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      iconColor: Colors.white,
                      collapsedIconColor: Colors.white70,
                      tilePadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      children: [
                        const Text(
                          'Your data never leaves your device. Checkmate is designed with privacy-first principles—zero cloud storage and zero accounts. All information is stored locally and removed completely when you uninstall.',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Support options (only visible in regular settings mode)
                if (!widget.isOnboarding)
                  Container(
                    decoration: BoxDecoration(
                      color:
                          isDark
                              ? colorScheme.surfaceContainerHighest
                              : Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        // Contact support option
                        ListTile(
                          title: const Text(
                            'Contact Us',
                            style: TextStyle(color: Colors.white),
                          ),
                          subtitle: const Text(
                            'checkmateapp@duck.com',
                            style: TextStyle(color: Colors.white70),
                          ),
                          leading: const Icon(
                            Icons.email_outlined,
                            color: Colors.white,
                          ),
                          onTap: () {
                            final currentContext = context;
                            final emailUri = Uri(
                              scheme: 'mailto',
                              path: 'checkmateapp@duck.com',
                            );

                            // Try email app, fallback to clipboard copy
                            canLaunchUrl(emailUri).then((canLaunch) {
                              if (canLaunch) {
                                launchUrl(emailUri);
                              } else {
                                Clipboard.setData(
                                  const ClipboardData(
                                    text: 'checkmateapp@duck.com',
                                  ),
                                ).then((_) {
                                  if (currentContext.mounted) {
                                    ScaffoldMessenger.of(
                                      currentContext,
                                    ).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Email copied to clipboard',
                                        ),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                });
                              }
                            });
                          },
                        ),

                        const Divider(
                          color: Colors.white24,
                          height: 1,
                          indent: 16,
                          endIndent: 16,
                        ),

                        // App store rating option
                        ListTile(
                          title: const Text(
                            'Rate Us on App Store',
                            style: TextStyle(color: Colors.white),
                          ),
                          subtitle: const Text(
                            'Love Checkmate? Let us know!',
                            style: TextStyle(color: Colors.white70),
                          ),
                          leading: const Icon(
                            Icons.star_border_rounded,
                            color: Colors.white,
                          ),
                          onTap: _openAppStore,
                        ),

                        const Divider(
                          color: Colors.white24,
                          height: 1,
                          indent: 16,
                          endIndent: 16,
                        ),

                        // Share app option
                        ListTile(
                          title: const Text(
                            'Share with Friends',
                            style: TextStyle(color: Colors.white),
                          ),
                          subtitle: const Text(
                            'Spread the word!',
                            style: TextStyle(color: Colors.white70),
                          ),
                          leading: const Icon(
                            Icons.ios_share,
                            color: Colors.white,
                          ),
                          onTap: _shareApp,
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 40),

                // Version info
                const Center(
                  child: Text(
                    'Version 1.0.0',
                    style: TextStyle(color: Colors.white60, fontSize: 14),
                  ),
                ),

                // Continue button during onboarding
                if (widget.isOnboarding)
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: FilledButton(
                      onPressed: () {
                        _savePaymentSettings();
                        Navigator.of(context).pushReplacementNamed('/landing');
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: colorScheme.primary,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Continue to App',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
