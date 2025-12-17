import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:checks_frontend/models/tab.dart';
import 'package:checks_frontend/screens/recent_bills/models/recent_bill_manager.dart';
import 'package:checks_frontend/screens/recent_bills/models/recent_bill_model.dart';
import 'package:checks_frontend/screens/recent_bills/billDetails/bill_details_screen.dart';
import 'package:checks_frontend/screens/quick_split/bill_entry/utils/currency_formatter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class TabDetailScreen extends StatefulWidget {
  final AppTab tab;

  const TabDetailScreen({super.key, required this.tab});

  @override
  State<TabDetailScreen> createState() => _TabDetailScreenState();
}

class _TabDetailScreenState extends State<TabDetailScreen> with SingleTickerProviderStateMixin {
  final _billsManager = RecentBillsManager();
  List<RecentBillModel> _allBills = [];
  List<RecentBillModel> _tabBills = [];
  bool _isLoading = true;
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

  Future<void> _loadBills() async {
    setState(() => _isLoading = true);
    
    final allBills = await _billsManager.getRecentBills();
    final tabBills = allBills.where((bill) => _currentTab.billIds.contains(bill.id)).toList();
    
    setState(() {
      _allBills = allBills;
      _tabBills = tabBills;
      _isLoading = false;
    });
  }

  Future<void> _addBillsToTab() async {
    HapticFeedback.mediumImpact();
    
    final availableBills = _allBills
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

    if (selectedBills != null && selectedBills.isNotEmpty && mounted) {
      setState(() {
        _currentTab = AppTab(
          id: _currentTab.id,
          name: _currentTab.name,
          createdAt: _currentTab.createdAt,
          billIds: [..._currentTab.billIds, ...selectedBills],
        );
      });
      
      await _saveTab();
      await _loadBills();
      
      _showSnackBar('Added ${selectedBills.length} bill${selectedBills.length == 1 ? '' : 's'}');
    }
  }

  Future<void> _saveTab() async {
    final prefs = await SharedPreferences.getInstance();
    final tabsJson = prefs.getString('tabs') ?? '[]';
    final List<dynamic> tabsList = jsonDecode(tabsJson);
    
    final tabIndex = tabsList.indexWhere((t) => t['id'] == _currentTab.id);
    if (tabIndex != -1) {
      tabsList[tabIndex] = {
        'id': _currentTab.id,
        'name': _currentTab.name,
        'createdAt': _currentTab.createdAt.toIso8601String(),
        'billIds': _currentTab.billIdsJson,
      };
      await prefs.setString('tabs', jsonEncode(tabsList));
    }
  }

  Future<void> _removeBill(int billId) async {
    setState(() {
      _currentTab = AppTab(
        id: _currentTab.id,
        name: _currentTab.name,
        createdAt: _currentTab.createdAt,
        billIds: _currentTab.billIds.where((id) => id != billId).toList(),
      );
    });
    
    await _saveTab();
    await _loadBills();
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
    return _tabBills.fold(0.0, (sum, bill) => sum + bill.total);
  }

  Map<String, double> _calculatePersonTotals() {
    final Map<String, double> personTotals = {};
    final Map<String, String> nameMapping = {};
    
    for (final bill in _tabBills) {
      final billShares = bill.generatePersonShares();
      
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
      backgroundColor: brightness == Brightness.dark ? colorScheme.surface : Colors.grey[50],
      appBar: AppBar(
        title: Text(
          _currentTab.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () {
            HapticFeedback.selectionClick();
            Navigator.pop(context, true);
          },
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
          : _tabBills.isEmpty
              ? _buildEmptyState()
              : Column(
                  children: [
                    _buildTotalCard(),
                    if (_calculatePersonTotals().isNotEmpty) _buildPersonTotalsCard(),
                    Expanded(child: _buildBillsList()),
                  ],
                ),
      floatingActionButton: _buildFAB(),
    );
  }

  Widget _buildEmptyState() {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: brightness == Brightness.dark ? 0.15 : 0.08),
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
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Add bills from your recent history\nto track this ${_currentTab.name.toLowerCase()}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                height: 1.5,
                color: colorScheme.onSurface.withValues(alpha: 0.7),
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

    return Container(
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
            color: colorScheme.primary.withValues(alpha: brightness == Brightness.dark ? 0.2 : 0.3),
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
            CurrencyFormatter.formatCurrency(total),
            style: TextStyle(
              color: brightness == Brightness.dark 
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
                color: brightness == Brightness.dark 
                    ? Colors.black.withValues(alpha: 0.8)
                    : Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonTotalsCard() {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final personTotals = _calculatePersonTotals();
    final sortedEntries = personTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final cardBgColor = brightness == Brightness.dark ? colorScheme.surface : Colors.white;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: brightness == Brightness.dark
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
                  child: Icon(Icons.people_alt, color: colorScheme.primary, size: 20),
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
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final entry = sortedEntries[index];
              return Row(
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
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      CurrencyFormatter.formatCurrency(entry.value),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBillsList() {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      itemCount: _tabBills.length,
      itemBuilder: (context, index) {
        final bill = _tabBills[index];

        return Dismissible(
          key: Key('bill_${bill.id}'),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.red.shade400, Colors.red.shade600],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.remove_circle_outline, color: Colors.white, size: 28),
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
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: brightness == Brightness.dark ? colorScheme.surface : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: brightness == Brightness.dark
                      ? Colors.black.withValues(alpha: 0.2)
                      : Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () async {
                  HapticFeedback.selectionClick();
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => BillDetailsScreen(bill: bill)),
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
                          color: colorScheme.primaryContainer.withValues(alpha: 0.6),
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
                                color: colorScheme.onSurface.withValues(alpha: 0.6),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              bill.participantSummary,
                              style: TextStyle(
                                color: colorScheme.onSurface.withValues(alpha: 0.5),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          CurrencyFormatter.formatCurrency(bill.total),
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
        );
      },
    );
  }

  Widget _buildFAB() {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: brightness == Brightness.dark ? 0.2 : 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        onPressed: _addBillsToTab,
        elevation: 0,
        backgroundColor: colorScheme.primary,
        foregroundColor: brightness == Brightness.dark ? Colors.black.withValues(alpha: 0.9) : Colors.white,
        icon: const Icon(Icons.add, size: 22),
        label: const Text(
          'Add Bills',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.5),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}

// Bill Selector Sheet
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
    final brightness = Theme.of(context).brightness;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      decoration: BoxDecoration(
        color: brightness == Brightness.dark ? colorScheme.surface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.onSurface.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.library_add, color: colorScheme.primary, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Add Bills to Tab',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    if (_selectedBillIds.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_selectedBillIds.length}',
                          style: TextStyle(
                            color: brightness == Brightness.dark 
                                ? Colors.black.withValues(alpha: 0.9)
                                : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: widget.bills.length,
              itemBuilder: (context, index) {
                final bill = widget.bills[index];
                final isSelected = _selectedBillIds.contains(bill.id);

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? colorScheme.primaryContainer.withValues(alpha: 0.3)
                        : (brightness == Brightness.dark 
                            ? colorScheme.surfaceContainerHighest 
                            : Colors.grey.shade50),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected 
                          ? colorScheme.primary
                          : colorScheme.outline.withValues(alpha: 0.2),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: CheckboxListTile(
                    value: isSelected,
                    onChanged: (checked) {
                      HapticFeedback.selectionClick();
                      setState(() {
                        if (checked == true) {
                          _selectedBillIds.add(bill.id);
                        } else {
                          _selectedBillIds.remove(bill.id);
                        }
                      });
                    },
                    title: Text(
                      bill.billName,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    subtitle: Text(
                      '${bill.formattedDate} • ${CurrencyFormatter.formatCurrency(bill.total)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    activeColor: colorScheme.primary,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.5)),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _selectedBillIds.isEmpty
                        ? null
                        : () {
                            HapticFeedback.mediumImpact();
                            Navigator.pop(context, _selectedBillIds.toList());
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: brightness == Brightness.dark 
                          ? Colors.black.withValues(alpha: 0.9)
                          : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      'Add ${_selectedBillIds.length}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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
        color: brightness == Brightness.dark ? colorScheme.surface : Colors.white,
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
              child: const Icon(Icons.remove_circle_outline, color: Colors.orange, size: 28),
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
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.5)),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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