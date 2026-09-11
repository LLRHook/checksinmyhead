import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:checks_frontend/models/tab.dart';
import 'package:checks_frontend/screens/tabs/tab_manager.dart';
import 'package:checks_frontend/screens/recent_bills/models/recent_bill_manager.dart';
import 'package:checks_frontend/screens/recent_bills/models/recent_bill_model.dart';
import 'package:checks_frontend/screens/recent_bills/billDetails/bill_details_screen.dart';
import 'package:checks_frontend/screens/quick_split/bill_entry/utils/currency_formatter.dart';
import 'package:checks_frontend/screens/quick_split/bill_entry/bill_entry_screen.dart';
import 'package:checks_frontend/models/person.dart';
import 'package:checks_frontend/services/api_service.dart';
import 'package:checks_frontend/screens/settings/services/preferences_service.dart';
import 'package:share_plus/share_plus.dart';

class TabDetailScreen extends StatefulWidget {
  final AppTab tab;

  const TabDetailScreen({super.key, required this.tab});

  @override
  State<TabDetailScreen> createState() => _TabDetailScreenState();
}

class _TabDetailScreenState extends State<TabDetailScreen>
    with SingleTickerProviderStateMixin {
  final _billsManager = RecentBillsManager();
  final _tabManager = TabManager();
  final _apiService = ApiService();
  List<RecentBillModel> _allBills = [];
  List<RecentBillModel> _tabBills = [];
  List<SettlementResponse> _settlements = [];
  List<TabMemberResponse> _members = [];
  bool _isLoading = true;
  bool _isFinalizing = false;
  late AppTab _currentTab;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _currentTab = widget.tab;
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadBills();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  String _formatCurrency(double value) {
    return CurrencyFormatter.formatCurrency(
      value,
      currencyCode: _currentTab.displayCurrency,
    );
  }

  Future<void> _loadBills() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    // Refresh tab from DB to get latest data (e.g. shareUrl after sync)
    if (_currentTab.id != null) {
      final refreshed = await _tabManager.getTabById(_currentTab.id!);
      if (refreshed != null) {
        _currentTab = refreshed;
      }
    }

    final allBills = await _billsManager.getRecentBills();
    final tabBills =
        allBills
            .where((bill) => _currentTab.billIds.contains(bill.id))
            .toList();

    await _loadSettlements();
    await _loadMembers();

    if (mounted) {
      setState(() {
        _allBills = allBills;
        _tabBills = tabBills;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMembers() async {
    if (_currentTab.backendId == null || _currentTab.accessToken == null) {
      return;
    }

    try {
      final members = await _apiService.getTabMembers(
        _currentTab.backendId!,
        _currentTab.accessToken!,
      );

      if (mounted) {
        setState(() => _members = members);
      }
    } on ApiException {
      // Members are non-critical; silently fail
    }
  }

  Future<void> _loadSettlements() async {
    if (_currentTab.backendId == null || _currentTab.accessToken == null) {
      return;
    }
    if (!_currentTab.isFinalized) return;

    try {
      final settlements = await _apiService.getSettlements(
        _currentTab.backendId!,
        _currentTab.accessToken!,
      );

      if (mounted) {
        setState(() => _settlements = settlements);
      }
    } on ApiException {
      // Settlements are non-critical; silently fail
    }
  }

  bool get _canFinalize {
    if (!_currentTab.isSynced) return false;
    if (_currentTab.isFinalized) return false;
    if (_tabBills.isEmpty && !_currentTab.isRemote) return false;
    // If tab has members, only the creator can finalize
    if (_members.isNotEmpty && !_currentTab.isCreator) return false;
    return true;
  }

  Future<void> _finalizeTab() async {
    if (!_canFinalize || _currentTab.id == null) return;

    // Show settlement preview / confirmation
    final personTotals = _calculatePersonTotals();
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _FinalizeConfirmSheet(personTotals: personTotals),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isFinalizing = true);

    final success = await _tabManager.finalizeTab(_currentTab.id!);

    if (mounted) {
      setState(() => _isFinalizing = false);

      if (success) {
        _showSnackBar('Tab finalized');
        await _loadBills();
      } else {
        _showSnackBar('Failed to finalize tab', isError: true);
      }
    }
  }

  Future<void> _toggleSettlementPaid(SettlementResponse settlement) async {
    if (_currentTab.backendId == null || _currentTab.accessToken == null) {
      return;
    }

    try {
      await _apiService.updateSettlement(
        _currentTab.backendId!,
        settlement.id,
        _currentTab.accessToken!,
        !settlement.paid,
      );

      if (mounted) {
        await _loadSettlements();
      }
    } on ApiException {
      // Toggle failed; silently fail
    }
  }

  Future<void> _addBillsToTab() async {
    HapticFeedback.mediumImpact();

    final availableBills =
        _allBills
            .where((bill) => !_currentTab.billIds.contains(bill.id))
            .toList();

    if (availableBills.isEmpty) {
      _showSnackBar('No bills available to add', isError: true);
      return;
    }

    final selectedBills = await showModalBottomSheet<List<int>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _BillSelectorSheet(bills: availableBills),
    );

    if (selectedBills != null &&
        selectedBills.isNotEmpty &&
        _currentTab.id != null &&
        mounted) {
      await _tabManager.addBillsToTab(_currentTab.id!, selectedBills);
      await _loadBills();

      _showSnackBar(
        'Added ${selectedBills.length} bill${selectedBills.length == 1 ? '' : 's'}',
      );
    }
  }

  Future<void> _addReceiptToTab() async {
    HapticFeedback.mediumImpact();
    final participants =
        _members
            .map(
              (member) => Person(name: member.displayName, color: Colors.blue),
            )
            .toList();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) =>
                BillEntryScreen(participants: participants, tab: _currentTab),
      ),
    );
    if (mounted) await _loadBills();
  }

  Future<void> _removeBill(int billId) async {
    if (_currentTab.id == null) return;
    await _tabManager.removeBillFromTab(_currentTab.id!, billId);
    await _loadBills();
  }

  Future<void> _chooseDisplayCurrency() async {
    if (_currentTab.id == null) return;
    const currencies = {
      'USD': 'US Dollar',
      'PEN': 'Peruvian Sol',
      'EUR': 'Euro',
      'GBP': 'British Pound',
      'CAD': 'Canadian Dollar',
      'AUD': 'Australian Dollar',
      'MXN': 'Mexican Peso',
      'BRL': 'Brazilian Real',
      'JPY': 'Japanese Yen',
      'CNY': 'Chinese Yuan',
      'INR': 'Indian Rupee',
      'CHF': 'Swiss Franc',
    };

    final selected = await showDialog<String>(
      context: context,
      builder:
          (context) => SimpleDialog(
            title: const Text('Tab display currency'),
            children:
                currencies.entries
                    .map(
                      (entry) => SimpleDialogOption(
                        onPressed: () => Navigator.pop(context, entry.key),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 48,
                              child: Text(
                                entry.key,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Expanded(child: Text(entry.value)),
                            if (entry.key == _currentTab.displayCurrency)
                              const Icon(Icons.check, size: 18),
                          ],
                        ),
                      ),
                    )
                    .toList(),
          ),
    );

    if (selected == null || selected == _currentTab.displayCurrency) return;
    await PreferencesService().setTabDisplayCurrency(_currentTab.id!, selected);
    if (_currentTab.backendId != null && _currentTab.accessToken != null) {
      try {
        await _apiService.updateTabDisplayCurrency(
          _currentTab.backendId!,
          _currentTab.accessToken!,
          selected,
          memberToken: _currentTab.memberToken,
        );
      } on ApiException {
        if (mounted) {
          _showSnackBar(
            'Saved on this device, but could not sync the tab currency.',
            isError: true,
          );
        }
      }
    }
    if (!mounted) return;
    setState(() {
      _currentTab = _currentTab.copyWith(displayCurrency: selected);
    });
    _showSnackBar('Tab totals will display in $selected');
  }

  void _shareTab() {
    if (_currentTab.shareUrl != null) {
      SharePlus.instance.share(
        ShareParams(
          text:
              'Check out "${_currentTab.name}" on Billington: ${_currentTab.shareUrl}',
        ),
      );
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;

    final colorScheme = Theme.of(context).colorScheme;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.info_outline : Icons.check_circle,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: isError ? Colors.orange.shade700 : colorScheme.primary,
      ),
    );
  }

  double _calculateTotal() {
    return _tabBills.fold(0.0, (sum, bill) => sum + bill.usdTotal);
  }

  // Known limitation: Person equality uses both name and color, so the same
  // person with different colors across bills appears as separate entries.
  // We mitigate this by aggregating on lowercase name below.
  Map<String, double> _calculatePersonTotals() {
    final Map<String, double> personTotals = {};
    final Map<String, String> nameMapping = {};

    for (final bill in _tabBills) {
      final billShares = bill.generateUSDPersonShares();

      billShares.forEach((person, amount) {
        final nameLower = person.name.toLowerCase();

        if (!nameMapping.containsKey(nameLower)) {
          nameMapping[nameLower] = person.name;
        }

        final displayName = nameMapping[nameLower]!;
        personTotals[displayName] = (personTotals[displayName] ?? 0.0) + amount;
      });
    }

    return personTotals;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    return Scaffold(
      backgroundColor:
          brightness == Brightness.dark ? colorScheme.surface : Colors.grey[50],
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _currentTab.name,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (_currentTab.isFinalized) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Finalized',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.green.shade700,
                  ),
                ),
              ),
            ],
          ],
        ),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          tooltip: 'Go back',
          onPressed: () {
            HapticFeedback.selectionClick();
            Navigator.pop(context, true);
          },
        ),
        actions: [
          if (_currentTab.shareUrl != null)
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Share tab',
              onPressed: _shareTab,
            ),
          if (!_currentTab.isFinalized)
            PopupMenuButton<String>(
              tooltip: 'More tab actions',
              onSelected: (value) {
                if (value == 'existing') _addBillsToTab();
                if (value == 'currency') _chooseDisplayCurrency();
              },
              itemBuilder:
                  (context) => const [
                    PopupMenuItem(
                      value: 'currency',
                      child: Text('Set display currency'),
                    ),
                    PopupMenuItem(
                      value: 'existing',
                      child: Text('Add existing bill'),
                    ),
                  ],
            ),
        ],
      ),
      body:
          _isLoading
              ? Center(
                child: CircularProgressIndicator(color: colorScheme.primary),
              )
              : _tabBills.isEmpty
              ? _buildEmptyState()
              : Column(
                children: [
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _loadBills,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 100),
                        children: [
                          if (_tabBills.isNotEmpty) _buildTotalCard(),
                          if (_members.isNotEmpty) _buildMembersCard(),
                          if (_currentTab.isFinalized &&
                              _settlements.isNotEmpty)
                            _buildSettlementsCard()
                          else if (_calculatePersonTotals().isNotEmpty)
                            _buildPersonTotalsCard(),
                          if (_tabBills.isNotEmpty) ..._buildBillCards(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      floatingActionButton: _currentTab.isFinalized ? null : _buildFAB(),
    );
  }

  Widget _buildEmptyState() {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(
                  alpha: brightness == Brightness.dark ? 0.15 : 0.08,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.receipt_long_outlined,
                size: 64,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'No Bills Yet',
              style: textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Add bills from your recent history\nto track this ${_currentTab.name.toLowerCase()}',
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge?.copyWith(
                height: 1.5,
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _addReceiptToTab,
              icon: const Icon(Icons.add),
              label: const Text('Add Receipt'),
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor:
                    brightness == Brightness.dark
                        ? Colors.black.withValues(alpha: 0.9)
                        : Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalCard() {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final total = _calculateTotal();

    return Semantics(
      label:
          'Tab total: ${_formatCurrency(total)}, ${_tabBills.length} bill${_tabBills.length == 1 ? '' : 's'}',
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colorScheme.primary,
              colorScheme.primary.withValues(alpha: 0.85),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withValues(
                alpha: brightness == Brightness.dark ? 0.2 : 0.3,
              ),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              'Total',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _formatCurrency(total),
              style: TextStyle(
                color:
                    brightness == Brightness.dark
                        ? Colors.black.withValues(alpha: 0.9)
                        : Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.bold,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_tabBills.length} bill${_tabBills.length == 1 ? '' : 's'}',
                style: TextStyle(
                  color:
                      brightness == Brightness.dark
                          ? Colors.black.withValues(alpha: 0.8)
                          : Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMembersCard() {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final cardBgColor =
        brightness == Brightness.dark ? colorScheme.surface : Colors.white;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color:
                brightness == Brightness.dark
                    ? Colors.black.withValues(alpha: 0.2)
                    : Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.group, size: 18, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Members',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              Text(
                '${_members.length}',
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                _members.map((member) {
                  final isCreator = member.role == 'creator';
                  return Semantics(
                    label:
                        '${member.displayName}${isCreator ? ', creator' : ', member'}',
                    child: Chip(
                      avatar:
                          isCreator
                              ? Icon(
                                Icons.star,
                                size: 16,
                                color: Colors.amber.shade700,
                              )
                              : CircleAvatar(
                                radius: 12,
                                backgroundColor: colorScheme.primary.withValues(
                                  alpha: 0.15,
                                ),
                                child: Text(
                                  member.displayName.isNotEmpty
                                      ? member.displayName[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                      label: Text(member.displayName),
                      labelStyle: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurface,
                      ),
                      backgroundColor:
                          brightness == Brightness.dark
                              ? colorScheme.surfaceContainerHighest
                              : Colors.grey.shade50,
                      side: BorderSide.none,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  );
                }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSettlementsCard() {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final cardBgColor =
        brightness == Brightness.dark ? colorScheme.surface : Colors.white;
    final paidCount = _settlements.where((s) => s.paid).length;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color:
                brightness == Brightness.dark
                    ? Colors.black.withValues(alpha: 0.2)
                    : Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_outlined,
                    color: Colors.green,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Settlements',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$paidCount/${_settlements.length} paid',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colorScheme.outline.withValues(alpha: 0.2)),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            itemCount: _settlements.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final settlement = _settlements[index];
              return Semantics(
                label:
                    '${settlement.personName}, ${_formatCurrency(settlement.amount)}, ${settlement.paid ? 'paid' : 'unpaid'}. Tap to toggle',
                button: true,
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _toggleSettlementPaid(settlement);
                  },
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor:
                            settlement.paid
                                ? Colors.green.withValues(alpha: 0.15)
                                : colorScheme.primaryContainer,
                        child:
                            settlement.paid
                                ? Icon(
                                  Icons.check,
                                  size: 18,
                                  color: Colors.green.shade700,
                                )
                                : Text(
                                  settlement.personName[0].toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.primary,
                                  ),
                                ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          settlement.personName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color:
                                settlement.paid
                                    ? colorScheme.onSurface.withValues(
                                      alpha: 0.5,
                                    )
                                    : colorScheme.onSurface,
                            decoration:
                                settlement.paid
                                    ? TextDecoration.lineThrough
                                    : null,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color:
                              settlement.paid
                                  ? Colors.green.withValues(alpha: 0.1)
                                  : colorScheme.primaryContainer.withValues(
                                    alpha: 0.6,
                                  ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _formatCurrency(settlement.amount),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color:
                                settlement.paid
                                    ? Colors.green.shade700
                                    : colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPersonTotalsCard() {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final personTotals = _calculatePersonTotals();
    final sortedEntries =
        personTotals.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    final cardBgColor =
        brightness == Brightness.dark ? colorScheme.surface : Colors.white;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color:
                brightness == Brightness.dark
                    ? Colors.black.withValues(alpha: 0.2)
                    : Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.people_alt,
                    color: colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Per Person',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colorScheme.outline.withValues(alpha: 0.2)),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            itemCount: sortedEntries.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final entry = sortedEntries[index];
              return Semantics(
                label: '${entry.key}: ${_formatCurrency(entry.value)}',
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: colorScheme.primaryContainer,
                      child: Text(
                        entry.key[0].toUpperCase(),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        entry.key,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withValues(
                          alpha: 0.6,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _formatCurrency(entry.value),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  List<Widget> _buildBillCards() {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    return _tabBills.map((bill) {
      return Dismissible(
        key: Key('bill_${bill.id}'),
        direction:
            _currentTab.isFinalized
                ? DismissDirection.none
                : DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.red.shade400, Colors.red.shade600],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(
            Icons.remove_circle_outline,
            color: Colors.white,
            size: 28,
          ),
        ),
        confirmDismiss: (_) async {
          HapticFeedback.mediumImpact();

          final confirmed = await showModalBottomSheet<bool>(
            context: context,
            backgroundColor: Colors.transparent,
            builder: (context) => _RemoveBillSheet(billName: bill.billName),
          );

          return confirmed ?? false;
        },
        onDismissed: (_) => _removeBill(bill.id),
        child: Container(
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          decoration: BoxDecoration(
            color:
                brightness == Brightness.dark
                    ? colorScheme.surface
                    : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color:
                    brightness == Brightness.dark
                        ? Colors.black.withValues(alpha: 0.2)
                        : Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Semantics(
            label:
                '${bill.billName}, ${_formatCurrency(bill.total)}, ${bill.formattedDate}${!_currentTab.isFinalized ? '. Swipe left to remove' : ''}',
            button: true,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () async {
                  HapticFeedback.selectionClick();
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => BillDetailsScreen(bill: bill),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer.withValues(
                            alpha: 0.6,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.receipt_long,
                          color: colorScheme.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              bill.billName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: colorScheme.onSurface,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              bill.formattedDate,
                              style: TextStyle(
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              bill.participantSummary,
                              style: TextStyle(
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.5,
                                ),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer.withValues(
                            alpha: 0.7,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _formatCurrency(bill.total),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildFAB() {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    // Show finalize button when ready
    if (_canFinalize) {
      return Container(
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.green.withValues(
                alpha: brightness == Brightness.dark ? 0.2 : 0.3,
              ),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: _isFinalizing ? null : _finalizeTab,
          elevation: 0,
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          icon:
              _isFinalizing
                  ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                  : const Icon(Icons.check_circle_outline, size: 22),
          label: Text(
            _isFinalizing ? 'Finalizing...' : 'Finalize',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      );
    }

    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(
              alpha: brightness == Brightness.dark ? 0.2 : 0.3,
            ),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        onPressed: _addReceiptToTab,
        elevation: 0,
        backgroundColor: colorScheme.primary,
        foregroundColor:
            brightness == Brightness.dark
                ? Colors.black.withValues(alpha: 0.9)
                : Colors.white,
        icon: const Icon(Icons.add, size: 22),
        label: const Text(
          'Add Receipt',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}

// Finalize confirmation sheet
class _FinalizeConfirmSheet extends StatelessWidget {
  final Map<String, double> personTotals;

  const _FinalizeConfirmSheet({required this.personTotals});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final sortedEntries =
        personTotals.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: BoxDecoration(
        color:
            brightness == Brightness.dark ? colorScheme.surface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.check_circle_outline,
                color: Colors.green,
                size: 28,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Finalize Tab',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This will lock the tab from further edits.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:
                    brightness == Brightness.dark
                        ? colorScheme.surfaceContainerHighest
                        : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    'Settlement Preview',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...sortedEntries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: colorScheme.primaryContainer,
                            child: Text(
                              entry.key[0].toUpperCase(),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              entry.key,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),
                          Text(
                            CurrencyFormatter.formatCurrency(entry.value),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      Navigator.pop(context, false);
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      side: BorderSide(
                        color: colorScheme.outline.withValues(alpha: 0.5),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      Navigator.pop(context, true);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Finalize',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
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
}

class _BillSelectorSheet extends StatefulWidget {
  final List<RecentBillModel> bills;

  const _BillSelectorSheet({required this.bills});

  @override
  State<_BillSelectorSheet> createState() => _BillSelectorSheetState();
}

class _BillSelectorSheetState extends State<_BillSelectorSheet> {
  final Set<int> _selectedBillIds = {};

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Material(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Add Bills to Tab',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children:
                      widget.bills.map((bill) {
                        return CheckboxListTile(
                          value: _selectedBillIds.contains(bill.id),
                          title: Text(bill.billName),
                          subtitle: Text(
                            '${bill.formattedDate} • ${CurrencyFormatter.formatCurrency(bill.total)}',
                          ),
                          onChanged:
                              (selected) => setState(() {
                                if (selected == true) {
                                  _selectedBillIds.add(bill.id);
                                } else {
                                  _selectedBillIds.remove(bill.id);
                                }
                              }),
                        );
                      }).toList(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed:
                          _selectedBillIds.isEmpty
                              ? null
                              : () => Navigator.pop(
                                context,
                                _selectedBillIds.toList(),
                              ),
                      child: Text('Add ${_selectedBillIds.length}'),
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
}

// Remove Bill Confirmation Sheet
class _RemoveBillSheet extends StatelessWidget {
  final String billName;

  const _RemoveBillSheet({required this.billName});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    return Container(
      decoration: BoxDecoration(
        color:
            brightness == Brightness.dark ? colorScheme.surface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.remove_circle_outline,
                color: Colors.orange,
                size: 28,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Remove from Tab',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Remove "$billName" from this tab? The bill will not be deleted.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      Navigator.pop(context, false);
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      side: BorderSide(
                        color: colorScheme.outline.withValues(alpha: 0.5),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      Navigator.pop(context, true);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Remove',
                      style: TextStyle(fontWeight: FontWeight.w600),
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
}
