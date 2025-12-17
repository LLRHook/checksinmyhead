// mobile/lib/screens/tabs/tab_detail_screen.dart

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

class _TabDetailScreenState extends State<TabDetailScreen> {
  final _billsManager = RecentBillsManager();
  List<RecentBillModel> _allBills = [];
  List<RecentBillModel> _tabBills = [];
  bool _isLoading = true;
  late AppTab _currentTab;

  @override
  void initState() {
    super.initState();
    _currentTab = widget.tab;
    _loadBills();
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
    // Filter out bills already in this tab
    final availableBills = _allBills
        .where((bill) => !_currentTab.billIds.contains(bill.id))
        .toList();

    if (availableBills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No bills available to add'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final selectedBills = await showDialog<List<int>>(
      context: context,
      builder: (context) => _BillSelectorDialog(bills: availableBills),
    );

    if (selectedBills != null && selectedBills.isNotEmpty) {
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
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added ${selectedBills.length} bill${selectedBills.length == 1 ? '' : 's'}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _saveTab() async {
    final prefs = await SharedPreferences.getInstance();
    final tabsJson = prefs.getString('tabs') ?? '[]';
    final List<dynamic> tabsList = jsonDecode(tabsJson);
    
    // Update this tab in the list
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

  double _calculateTotal() {
    return _tabBills.fold(0.0, (sum, bill) => sum + bill.total);
  }

Map<String, double> _calculatePersonTotals() {
  final Map<String, double> personTotals = {};
  final Map<String, String> nameMapping = {}; // lowercase -> original case
  
  for (final bill in _tabBills) {
    final billShares = bill.generatePersonShares();
    
    billShares.forEach((person, amount) {
      final nameLower = person.name.toLowerCase();
      
      // Use the first occurrence's capitalization
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

    final scaffoldBgColor =
        brightness == Brightness.dark ? colorScheme.surface : Colors.grey[50];

    return Scaffold(
        backgroundColor: scaffoldBgColor,
        appBar: AppBar(
          title: Text(
            _currentTab.name,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: () {
              HapticFeedback.selectionClick();
              Navigator.pop(context, true); // Return true to signal changes
            },
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _tabBills.isEmpty
                ? _buildEmptyState()
                : Column(
                    children: [
                      _buildTotalCard(),
                      _buildPersonTotalsCard(),
                      Expanded(
                        child: _buildBillsList(),
                      ),
                    ],
                  ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _addBillsToTab,
          icon: const Icon(Icons.add),
          label: const Text('Add Bills'),
        ),
      );
  }

  Widget _buildTotalCard() {
    final colorScheme = Theme.of(context).colorScheme;
    final total = _calculateTotal();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colorScheme.primary, colorScheme.primary.withValues(alpha: 0.8)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Total',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            CurrencyFormatter.formatCurrency(total),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_tabBills.length} bill${_tabBills.length == 1 ? '' : 's'}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
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
    
    if (personTotals.isEmpty) return const SizedBox.shrink();

    // Sort by amount (highest first)
    final sortedEntries = personTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: brightness == Brightness.dark
            ? colorScheme.surface
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: brightness == Brightness.dark
              ? colorScheme.outline.withValues(alpha: 0.3)
              : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.people_outline,
                  size: 20,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Per Person',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: sortedEntries.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final entry = sortedEntries[index];
              return Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: colorScheme.primaryContainer,
                    child: Text(
                      entry.key[0].toUpperCase(),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      CurrencyFormatter.formatCurrency(entry.value),
                      style: TextStyle(
                        fontSize: 15,
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

  Widget _buildEmptyState() {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 80,
              color: colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'No Bills Yet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Add bills from your recent history to track this trip',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBillsList() {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _tabBills.length,
      itemBuilder: (context, index) {
        final bill = _tabBills[index];

        return Dismissible(
          key: Key('bill_${bill.id}'),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.remove_circle_outline, color: Colors.white),
          ),
          confirmDismiss: (direction) async {
            return await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Remove from Tab'),
                content: Text('Remove "${bill.billName}" from this tab? The bill will not be deleted.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Remove'),
                  ),
                ],
              ),
            );
          },
          onDismissed: (direction) {
            _removeBill(bill.id);
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: brightness == Brightness.dark
                  ? colorScheme.surface
                  : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              title: Text(
                bill.billName,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    bill.formattedDate,
                    style: TextStyle(
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    bill.participantSummary,
                    style: TextStyle(
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  CurrencyFormatter.formatCurrency(bill.total),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ),
              onTap: () async {
                HapticFeedback.selectionClick();
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BillDetailsScreen(bill: bill),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

// Dialog for selecting bills to add
class _BillSelectorDialog extends StatefulWidget {
  final List<RecentBillModel> bills;

  const _BillSelectorDialog({required this.bills});

  @override
  State<_BillSelectorDialog> createState() => _BillSelectorDialogState();
}

class _BillSelectorDialogState extends State<_BillSelectorDialog> {
  final Set<int> _selectedBillIds = {};

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('Add Bills to Tab'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: widget.bills.length,
          itemBuilder: (context, index) {
            final bill = widget.bills[index];
            final isSelected = _selectedBillIds.contains(bill.id);

            return CheckboxListTile(
              value: isSelected,
              onChanged: (checked) {
                setState(() {
                  if (checked == true) {
                    _selectedBillIds.add(bill.id);
                  } else {
                    _selectedBillIds.remove(bill.id);
                  }
                });
              },
              title: Text(bill.billName),
              subtitle: Text(
                '${bill.formattedDate} • ${CurrencyFormatter.formatCurrency(bill.total)}',
              ),
              activeColor: colorScheme.primary,
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _selectedBillIds.isEmpty
              ? null
              : () => Navigator.pop(context, _selectedBillIds.toList()),
          child: Text('Add ${_selectedBillIds.length}'),
        ),
      ],
    );
  }
}