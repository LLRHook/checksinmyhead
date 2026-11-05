import 'package:checks_frontend/screens/participant_identity_panel.dart';
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
    this.tabId,
    this.memberToken,
    this.api,
  });

  final String billId;
  final String token;
  final String? tabId;
  final String? memberToken;
  final ApiService? api;

  @override
  State<LazyBillClaimScreen> createState() => _LazyBillClaimScreenState();
}

class _LazyBillClaimScreenState extends State<LazyBillClaimScreen> {
  late final ApiService _api = widget.api ?? ApiService();
  Map<String, dynamic>? _bill;
  String _name = '';
  int? _participantId;
  String _suggestedName = '';
  bool _loading = true;
  bool _saving = false;
  bool _paying = false;
  String? _error;
  bool _showPayment = false;
  bool _claimSavedNeedsRead = false;
  bool _resumePaymentOnRead = false;
  Map<int, List<Map<String, dynamic>>>? _draftAssignments;

  String get _nameKey => 'lazy_bill_name_${widget.billId}';

  @override
  void initState() {
    super.initState();
    _loadBill();
  }

  Future<void> _loadBill() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bill = await _api.getCurrentBill(
        billId: widget.billId,
        token: widget.token,
        tabId: widget.tabId,
        memberToken: widget.memberToken,
      );
      final profileName = await PreferencesService().getDisplayName();
      if (!mounted) return;
      setState(() {
        _bill = bill;
        final selected =
            (bill['participants'] as List? ?? [])
                .whereType<Map<String, dynamic>>()
                .where((p) => p['participant_id'] == _participantId)
                .firstOrNull;
        _name = selected == null ? '' : selected['label'] as String;
        // Legacy names remain suggestions for an explicit new occurrence only.
        _suggestedName = prefs.getString(_nameKey) ?? profileName ?? '';
        _draftAssignments = null;
        _loading = false;
        _claimSavedNeedsRead = false;
        _showPayment = _resumePaymentOnRead && _hasPaymentShare;
        _error =
            _resumePaymentOnRead && !_showPayment
                ? 'Selection saved. The current amount is unavailable; review the current receipt before payment.'
                : null;
        _resumePaymentOnRead = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error =
            _claimSavedNeedsRead
                ? 'Selection saved. Current total is unavailable. Retry current total to read it.'
                : error is ApiException
                ? error.message
                : 'Could not load this bill.';
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

  List<Map<String, dynamic>> _assignmentsFor(Map<String, dynamic> item) =>
      _draftAssignments?[item['id'] as int] ?? _originalAssignments(item);

  List<Map<String, dynamic>> _originalAssignments(Map<String, dynamic> item) =>
      ((item['assignments'] as List<dynamic>?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();

  bool get _selectionChanged {
    return _items.any(
      (item) =>
          !lazyAssignmentsEqual(
            _assignmentsFor(item),
            _originalAssignments(item),
          ),
    );
  }

  Map<String, dynamic>? get _myShare {
    for (final share in _shares) {
      if (_participantId != null && share['participant_id'] == _participantId) {
        return share;
      }
    }
    return null;
  }

  bool get _hasPaymentShare =>
      _bill?['identity_review_status'] == 'ready' &&
      _myShare != null &&
      ['total', 'subtotal', 'tax_share', 'tip_share'].every((field) {
        final value = _myShare![field];
        return value is num && value.isFinite;
      });

  bool get _canMarkPaid {
    if (_myShare == null) return false;
    if (widget.tabId == null) {
      return true; // Exact source capability, independent authority.
    }
    final p =
        (_bill?['participants'] as List? ?? [])
            .whereType<Map<String, dynamic>>()
            .where((p) => p['participant_id'] == _participantId)
            .firstOrNull;
    return p?['binding_state'] == 'confirmed' &&
        p?['member_id'] != null &&
        p?['member_id'] == _bill?['viewer_member_id'];
  }

  String get _currency => _bill?['currency_code'] as String? ?? 'USD';

  Future<void> _chooseName() async {
    setState(
      () =>
          _error =
              'Choose or add an occurrence in Receipt participants. Suggested label: $_suggestedName',
    );
  }

  Future<void> _toggleItem(Map<String, dynamic> item) async {
    if (_claimSavedNeedsRead) return;
    if (!canChangeLazyBillSelection(
      saving: _saving,
      paid: _myShare?['paid'] == true,
    )) {
      return;
    }
    if (_participantId == null) {
      await _chooseName();
      if (_participantId == null) return;
    }
    final assignments = _assignmentsFor(item);
    final assignedToMe = assignments.any(
      (assignment) =>
          _participantId != null &&
          assignment['participant_id'] == _participantId,
    );
    final nextAssignments =
        assignedToMe
            ? removeLazyAssignmentLeavingRemainder(assignments, _participantId!)
            : setLazyAssignmentPercentage(
              assignments,
              _participantId!,
              remainingLazyPercentage(assignments),
            );
    setState(() {
      _setDraftAssignments(item['id'] as int, nextAssignments);
      _error = null;
    });
  }

  void _setDraftAssignments(
    int itemId,
    List<Map<String, dynamic>> assignments,
  ) {
    _draftAssignments = {...?_draftAssignments, itemId: assignments};
  }

  Future<void> _editSplit(Map<String, dynamic> item) async {
    if (_saving || _claimSavedNeedsRead || _myShare?['paid'] == true) return;
    if (_participantId == null) {
      await _chooseName();
      if (_participantId == null || !mounted) return;
    }
    final assignments = _assignmentsFor(item);
    Map<String, dynamic>? myAssignment;
    for (final assignment in assignments) {
      if (_participantId != null &&
          assignment['participant_id'] == _participantId) {
        myAssignment = assignment;
        break;
      }
    }
    final available = remainingLazyPercentage(
      assignments,
      excludingPerson: _participantId,
    );
    if (available < 1 && myAssignment == null) return;
    final maximum = available.floor().clamp(1, 100);
    var percentage =
        myAssignment == null
            ? maximum
            : (myAssignment['percentage'] as num).round().clamp(1, maximum);
    final result = await showDialog<int>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: Text('Split ${item['name'] as String? ?? 'item'}'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Choose how much you had. The rest stays available for someone else to claim.',
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('You · $percentage%'),
                          Text(
                            '${(available - percentage).round()}% unclaimed',
                          ),
                        ],
                      ),
                      Slider(
                        value: percentage.toDouble(),
                        min: 1,
                        max: maximum.toDouble(),
                        divisions: maximum > 1 ? maximum - 1 : null,
                        label: '$percentage%',
                        onChanged:
                            (value) => setDialogState(
                              () => percentage = value.round(),
                            ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, percentage),
                      child: const Text('Apply split'),
                    ),
                  ],
                ),
          ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _setDraftAssignments(
        item['id'] as int,
        setLazyAssignmentPercentage(
          assignments,
          _participantId!,
          result.toDouble(),
        ),
      );
      _error = null;
    });
  }

  Future<void> _reviewSelection() async {
    if (_participantId == null || _bill?['identity_review_status'] != 'ready') {
      setState(
        () =>
            _error =
                'Choose a current receipt occurrence. Recorded ownership needing review cannot produce a payment amount.',
      );
      return;
    }
    if (_saving || _claimSavedNeedsRead || _myShare?['paid'] == true) return;
    final updates = <Map<String, dynamic>>[];
    for (final item in _items) {
      final assignments = _assignmentsFor(item);
      if (lazyAssignmentsEqual(assignments, _originalAssignments(item))) {
        continue;
      }
      updates.add({
        'item_id': item['id'],
        'expected_updated_at': item['updated_at'],
        'assignments': assignments,
      });
    }
    if (updates.isEmpty) {
      setState(() {
        _showPayment = _hasPaymentShare;
        if (!_showPayment) {
          _error =
              'The current amount is unavailable; refresh the receipt before payment.';
        }
      });
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
        updates:
            updates
                .map(
                  (u) => {
                    ...u,
                    'assignments':
                        (u['assignments'] as List)
                            .map(
                              (a) => {
                                'participant_id': a['participant_id'],
                                'percentage': a['percentage'],
                              },
                            )
                            .toList(),
                  },
                )
                .toList(),
        tabId: widget.tabId,
        memberToken: widget.memberToken,
        expectedRevision: _bill!['identity_revision'] as int,
      );
      if (!mounted) return;
      if (updatedBill == null) {
        setState(() {
          _draftAssignments = null;
          _claimSavedNeedsRead = true;
          _resumePaymentOnRead = true;
          _showPayment = false;
        });
        await _loadBill();
      } else {
        setState(() {
          _bill = updatedBill;
          _draftAssignments = null;
          _showPayment = _hasPaymentShare;
          if (!_showPayment) {
            _error =
                'Selection saved. The current amount is unavailable; refresh the receipt before payment.';
          }
        });
      }
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

  Future<void> _markPaid([Map<String, dynamic>? exactSourceShare]) async {
    final share = exactSourceShare ?? _myShare;
    if (share == null ||
        share['id'] is! int ||
        share['id'] <= 0 ||
        (exactSourceShare == null ? !_canMarkPaid : widget.tabId != null)) {
      return;
    }
    setState(() => _paying = true);
    try {
      if (widget.tabId != null) {
        if (widget.memberToken == null) {
          throw ApiException(
            'Recover your tab membership before marking paid.',
          );
        }
        await _api.updateTabBillPaid(
          tabId: widget.tabId!,
          billId: widget.billId,
          token: widget.token,
          memberToken: widget.memberToken!,
          shareId: share['id'] as int,
          paid: true,
        );
      } else {
        await _api.updateSharedBillPaid(
          billId: widget.billId,
          shareId: share['id'] as int,
          token: widget.token,
          paid: true,
        );
      }
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
    final total = (_myShare?['total'] as num?)?.toDouble();
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
          ParticipantIdentityPanel(
            bill: bill,
            token: widget.token,
            api: _api,
            tabId: widget.tabId,
            memberToken: widget.memberToken,
            selectedId: _participantId,
            onChanged: _loadBill,
            onParticipantChanged: (result) {
              if (result.participant.billId != _bill!['id']) return;
              final people =
                  (_bill!['participants'] as List).cast<Map<String, dynamic>>();
              setState(
                () =>
                    _bill = {
                      ..._bill!,
                      'identity_revision': result.revision,
                      'participants': [
                        for (final p in people)
                          if (p['participant_id'] == result.participant.id)
                            result.participant.toJson()
                          else
                            p,
                        if (!people.any(
                          (p) => p['participant_id'] == result.participant.id,
                        ))
                          result.participant.toJson(),
                      ],
                    },
              );
            },
            onSelected: (id) {
              final p =
                  (_bill!['participants'] as List)
                      .cast<Map<String, dynamic>>()
                      .where((p) => p['participant_id'] == id)
                      .firstOrNull;
              if (p == null) return;
              setState(() {
                _participantId = id;
                _name = p['label'] as String;
                _draftAssignments = null;
              });
            },
          ),
          if (bill['identity_review_status'] != 'ready')
            Card(
              child: Column(
                children: [
                  const ListTile(
                    title: Text('Recorded result; ownership needs review'),
                  ),
                  for (final (index, share) in _shares.indexed)
                    ListTile(
                      title: Text(
                        '${'${share['person_name'] ?? ''}'.isEmpty ? 'Unnamed' : share['person_name']} · ${share['id'] is int && share['id'] > 0 ? 'recorded row #${share['id']}' : 'recorded occurrence ${index + 1}'}',
                      ),
                      subtitle: Text(
                        share['paid'] == true
                            ? 'Marked paid (manual)'
                            : 'Not marked paid',
                      ),
                      trailing: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            share['total'] is num &&
                                    (share['total'] as num).isFinite
                                ? CurrencyFormatter.formatCurrency(
                                  (share['total'] as num).toDouble(),
                                  currencyCode: _currency,
                                )
                                : 'Amount unavailable',
                          ),
                          if (widget.tabId == null &&
                              share['id'] is int &&
                              share['id'] > 0)
                            TextButton(
                              onPressed:
                                  _paying ? null : () => _markPaid(share),
                              child: const Text('Mark recorded row paid'),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
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
                        final assignments = _assignmentsFor(item);
                        final mine = assignments.any(
                          (assignment) =>
                              _participantId != null &&
                              assignment['participant_id'] == _participantId,
                        );
                        final myAssignment = assignments.where(
                          (assignment) =>
                              _participantId != null &&
                              assignment['participant_id'] == _participantId,
                        );
                        final myPercentage =
                            myAssignment.isEmpty
                                ? 0.0
                                : (myAssignment.first['percentage'] as num)
                                    .toDouble();
                        final paid = isLazyItemFullyPaid(assignments, _shares);
                        final locked =
                            _claimSavedNeedsRead ||
                            isPaid ||
                            paid ||
                            bill['identity_review_status'] != 'ready' ||
                            (widget.tabId == null &&
                                (bill['lazy_mode'] != true ||
                                    bill['tab_id'] != null));
                        final available = remainingLazyPercentage(assignments);
                        final unavailable = !mine && available < 1;
                        final canChange = canChangeLazyBillSelection(
                          saving: _saving,
                          paid: locked,
                        );
                        return ListTile(
                          enabled: canChange && !unavailable,
                          onTap: () => _toggleItem(item),
                          leading: Checkbox(
                            value: mine,
                            onChanged:
                                !canChange || unavailable
                                    ? null
                                    : (_) => _toggleItem(item),
                          ),
                          title: Text(item['name'] as String? ?? 'Item'),
                          subtitle: Text(
                            locked
                                ? isPaid
                                    ? 'Paid'
                                    : 'Part of this item paid'
                                : unavailable
                                ? 'Taken by ${assignments.first['person_name']}'
                                : mine && myPercentage < 100
                                ? '${myPercentage.round()}% · ${CurrencyFormatter.formatCurrency((((item['price'] as num?)?.toDouble() ?? 0) * myPercentage / 100), currencyCode: _currency)}'
                                : assignments.isNotEmpty && available < 100
                                ? '${available.floor()}% unclaimed'
                                : CurrencyFormatter.formatCurrency(
                                  (item['price'] as num?)?.toDouble() ?? 0,
                                  currencyCode: _currency,
                                ),
                          ),
                          trailing: IconButton(
                            tooltip: 'Edit split for ${item['name']}',
                            onPressed:
                                !canChange || unavailable
                                    ? null
                                    : () => _editSplit(item),
                            icon: const Icon(Icons.people_alt_outlined),
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
            if (_claimSavedNeedsRead)
              TextButton(
                onPressed: _saving ? null : _loadBill,
                child: const Text('Retry current total'),
              ),
            if (_selectionChanged && !isPaid) ...[
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
              CurrencyFormatter.formatCurrency(total!, currencyCode: _currency),
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
                        (_myShare!['subtotal'] as num).toDouble(),
                        currencyCode: _currency,
                      ),
                    ),
                  ),
                  ListTile(
                    title: const Text('Tax'),
                    trailing: Text(
                      CurrencyFormatter.formatCurrency(
                        (_myShare!['tax_share'] as num).toDouble(),
                        currencyCode: _currency,
                      ),
                    ),
                  ),
                  ListTile(
                    title: const Text('Tip'),
                    trailing: Text(
                      CurrencyFormatter.formatCurrency(
                        (_myShare!['tip_share'] as num).toDouble(),
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
              onPressed: _paying || !_canMarkPaid ? null : _markPaid,
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
