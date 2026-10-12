import 'package:checks_frontend/screens/quick_split/bill_entry/utils/currency_formatter.dart';
import 'package:checks_frontend/services/api_service.dart';
import 'package:checks_frontend/screens/lazy_bill_claim_state.dart';
import 'package:checks_frontend/screens/settings/services/preferences_service.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class LazyBillClaimScreen extends StatefulWidget {
  const LazyBillClaimScreen({
    super.key,
    required this.billId,
    required this.token,
  });

  final String billId;
  final String token;

  @override
  State<LazyBillClaimScreen> createState() => _LazyBillClaimScreenState();
}

class _LazyBillClaimScreenState extends State<LazyBillClaimScreen> {
  final ApiService _api = ApiService();
  Map<String, dynamic>? _bill;
  String _name = '';
  bool _loading = true;
  bool _saving = false;
  bool _paying = false;
  String? _error;
  bool _showPayment = false;
  Set<int>? _selectedItemIds;

  String get _nameKey => 'lazy_bill_name_${widget.billId}';

  @override
  void initState() {
    super.initState();
    _loadBill();
  }

  Future<void> _loadBill() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bill = await _api.getSharedBill(widget.billId, widget.token);
      final profileName = await PreferencesService().getDisplayName();
      if (bill['lazy_mode'] != true) {
        throw ApiException('This link is not a lazy bill');
      }
      if (!mounted) return;
      setState(() {
        _bill = bill;
        _name = prefs.getString(_nameKey) ?? profileName ?? '';
        _selectedItemIds = _assignedItemIds(bill, _name);
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error =
            error is ApiException ? error.message : 'Could not load this bill.';
      });
    }
  }

  List<Map<String, dynamic>> get _items =>
      ((_bill?['items'] as List<dynamic>?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();

  List<Map<String, dynamic>> get _shares =>
      ((_bill?['person_shares'] as List<dynamic>?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();

  Set<int> _assignedItemIds(Map<String, dynamic> bill, String name) {
    if (name.isEmpty) return {};
    return ((bill['items'] as List<dynamic>?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .where((item) {
          final assignments =
              (item['assignments'] as List<dynamic>?) ?? const [];
          return assignments.whereType<Map<String, dynamic>>().any(
            (assignment) =>
                (assignment['person_name'] as String? ?? '').toLowerCase() ==
                name.toLowerCase(),
          );
        })
        .map((item) => item['id'] as int)
        .toSet();
  }

  Set<int> get _selectedItems =>
      _selectedItemIds ?? _assignedItemIds(_bill ?? {}, _name);

  Map<String, dynamic>? get _myShare {
    for (final share in _shares) {
      if ((share['person_name'] as String? ?? '').toLowerCase() ==
          _name.toLowerCase()) {
        return share;
      }
    }
    return null;
  }

  String get _currency => _bill?['currency_code'] as String? ?? 'USD';

  Future<void> _chooseName() async {
    final controller = TextEditingController(text: _name);
    final name = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('What should we call you?'),
            content: TextField(
              controller: controller,
              autofocus: true,
              maxLength: 30,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'Your name'),
              onSubmitted: (value) => Navigator.pop(context, value.trim()),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, controller.text.trim()),
                child: const Text('Continue'),
              ),
            ],
          ),
    );
    if (name == null || name.trim().isEmpty || name.trim().length > 30) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nameKey, name.trim());
    if (!mounted) return;
    setState(() {
      _name = name.trim();
      _selectedItemIds = _assignedItemIds(_bill ?? {}, _name);
    });
  }

  Future<void> _toggleItem(Map<String, dynamic> item) async {
    if (!canChangeLazyBillSelection(
      saving: _saving,
      paid: _myShare?['paid'] == true,
    )) {
      return;
    }
    if (_name.isEmpty) {
      await _chooseName();
      if (_name.isEmpty) return;
    }
    final assignments =
        ((item['assignments'] as List<dynamic>?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList();
    final assignedToMe = assignments.any(
      (assignment) =>
          (assignment['person_name'] as String? ?? '').toLowerCase() ==
          _name.toLowerCase(),
    );
    final mine = _selectedItems.contains(item['id'] as int);
    if (!mine && assignments.isNotEmpty && !assignedToMe) return;
    if (assignedToMe && assignments.length > 1) return;

    final selected = _selectedItems.toSet();
    setState(() {
      if (mine) {
        selected.remove(item['id'] as int);
      } else {
        selected.add(item['id'] as int);
      }
      _selectedItemIds = selected;
      _error = null;
    });
  }

  Future<void> _reviewSelection() async {
    if (_saving || _myShare?['paid'] == true) return;
    final selected = _selectedItems.toSet();
    final updates = <Map<String, dynamic>>[];
    for (final item in _items) {
      final assignments =
          ((item['assignments'] as List<dynamic>?) ?? const [])
              .whereType<Map<String, dynamic>>()
              .toList();
      final currentlyMine = assignments.any(
        (assignment) =>
            (assignment['person_name'] as String? ?? '').toLowerCase() ==
            _name.toLowerCase(),
      );
      final shouldBeMine = selected.contains(item['id'] as int);
      if (currentlyMine == shouldBeMine) continue;
      updates.add({
        'item_id': item['id'],
        'expected_updated_at': item['updated_at'],
        'assignments':
            shouldBeMine
                ? [
                  {'person_name': _name, 'percentage': 100},
                ]
                : <Map<String, dynamic>>[],
      });
    }
    if (updates.isEmpty) {
      setState(() => _showPayment = true);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updatedBill = await _api.updateLazyBillItemAssignments(
        billId: widget.billId,
        token: widget.token,
        updates: updates,
      );
      if (!mounted) return;
      setState(() {
        _bill = updatedBill;
        _selectedItemIds = selected;
        _showPayment = true;
      });
    } catch (error) {
      await _loadBill();
      if (mounted) {
        setState(
          () =>
              _error =
                  error is ApiException
                      ? error.message
                      : 'Could not save your selection. Refresh and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _markPaid() async {
    final share = _myShare;
    if (share == null) return;
    setState(() => _paying = true);
    try {
      await _api.updateSharedBillPaid(
        billId: widget.billId,
        shareId: share['id'] as int,
        token: widget.token,
        paid: true,
      );
      if (mounted && _bill != null) {
        final updatedShares =
            _shares
                .map(
                  (candidate) =>
                      candidate['id'] == share['id']
                          ? {...candidate, 'paid': true}
                          : candidate,
                )
                .toList();
        setState(() {
          _bill = {..._bill!, 'person_shares': updatedShares};
          _showPayment = false;
        });
      }
      if (mounted) {
        Navigator.of(
          context,
          rootNavigator: true,
        ).pushNamedAndRemoveUntil('/landing', (route) => false);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not save payment status. Try again.');
      }
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  Future<void> _payWithVenmo(double amount) async {
    final methods = (_bill?['payment_methods'] as List<dynamic>?) ?? const [];
    Map<String, dynamic>? venmo;
    for (final method in methods.whereType<Map<String, dynamic>>()) {
      if ((method['name'] as String? ?? '').toLowerCase().contains('venmo')) {
        venmo = method;
        break;
      }
    }
    if (venmo == null) return;
    final uri = Uri(
      scheme: 'venmo',
      host: 'paycharge',
      queryParameters: {
        'txn': 'pay',
        'recipients': (venmo['identifier'] as String? ?? '').replaceFirst(
          '@',
          '',
        ),
        'amount': amount.toStringAsFixed(2),
        'note': _bill?['name'] as String? ?? 'Billington bill',
      },
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null && _bill == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Shared bill')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_error!, textAlign: TextAlign.center),
          ),
        ),
      );
    }
    final bill = _bill!;
    final total = (_myShare?['total'] as num?)?.toDouble() ?? 0;
    final isPaid = _myShare?['paid'] == true;
    final venmoExists = ((_bill?['payment_methods'] as List<dynamic>?) ??
            const [])
        .whereType<Map<String, dynamic>>()
        .any(
          (method) =>
              (method['name'] as String? ?? '').toLowerCase().contains('venmo'),
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(bill['name'] as String? ?? 'Choose your items'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          if (!_showPayment) ...[
            Text(
              'Choose what you had',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isPaid
                  ? 'Your share is marked paid. Your items are locked.'
                  : _name.isEmpty
                  ? 'Tap an item to get started.'
                  : 'Picking as $_name',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (final item in _items)
                    Builder(
                      builder: (context) {
                        final assignments =
                            ((item['assignments'] as List<dynamic>?) ??
                                    const [])
                                .whereType<Map<String, dynamic>>()
                                .toList();
                        final mine = _selectedItems.contains(item['id'] as int);
                        final unavailable = assignments.any(
                          (assignment) =>
                              (assignment['person_name'] as String? ?? '')
                                  .toLowerCase() !=
                              _name.toLowerCase(),
                        );
                        final canChange = canChangeLazyBillSelection(
                          saving: _saving,
                          paid: isPaid,
                        );
                        final locked = isPaid;
                        return ListTile(
                          enabled:
                              canChange &&
                              !unavailable &&
                              !(mine && assignments.length > 1),
                          onTap: () => _toggleItem(item),
                          leading: Checkbox(
                            value: mine,
                            onChanged:
                                !canChange ||
                                        unavailable ||
                                        (mine && assignments.length > 1)
                                    ? null
                                    : (_) => _toggleItem(item),
                          ),
                          title: Text(item['name'] as String? ?? 'Item'),
                          subtitle: Text(
                            locked
                                ? 'Paid'
                                : unavailable
                                ? 'Taken by ${assignments.first['person_name']}'
                                : CurrencyFormatter.formatCurrency(
                                  (item['price'] as num?)?.toDouble() ?? 0,
                                  currencyCode: _currency,
                                ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            if (_selectedItems.isNotEmpty && !isPaid) ...[
              const SizedBox(height: 18),
              FilledButton(
                onPressed: _saving ? null : _reviewSelection,
                child: Text(_saving ? 'Saving selection…' : 'Review total'),
              ),
            ],
          ] else ...[
            Text('Your total', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              CurrencyFormatter.formatCurrency(total, currencyCode: _currency),
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  ListTile(
                    title: const Text('Your items'),
                    trailing: Text(
                      CurrencyFormatter.formatCurrency(
                        (_myShare?['subtotal'] as num?)?.toDouble() ?? 0,
                        currencyCode: _currency,
                      ),
                    ),
                  ),
                  ListTile(
                    title: const Text('Tax'),
                    trailing: Text(
                      CurrencyFormatter.formatCurrency(
                        (_myShare?['tax_share'] as num?)?.toDouble() ?? 0,
                        currencyCode: _currency,
                      ),
                    ),
                  ),
                  ListTile(
                    title: const Text('Tip'),
                    trailing: Text(
                      CurrencyFormatter.formatCurrency(
                        (_myShare?['tip_share'] as num?)?.toDouble() ?? 0,
                        currencyCode: _currency,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (venmoExists)
              OutlinedButton.icon(
                onPressed: () => _payWithVenmo(total),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Pay with Venmo'),
              ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _paying ? null : _markPaid,
              child: Text(_paying ? 'Saving…' : 'Mark as paid'),
            ),
            TextButton(
              onPressed: () => setState(() => _showPayment = false),
              child: const Text('Back to items'),
            ),
          ],
        ],
      ),
    );
  }
}
