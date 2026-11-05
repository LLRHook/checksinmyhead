import 'dart:convert';
import 'package:checks_frontend/models/participant_identity.dart';
import 'package:checks_frontend/models/person.dart';
import 'package:checks_frontend/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A selector is persisted only after a scoped current read. It is never proof.
class ParticipantIdentityPanel extends StatefulWidget {
  const ParticipantIdentityPanel({
    super.key,
    required this.bill,
    required this.token,
    required this.onChanged,
    this.onSelected,
    this.selectedId,
    this.tabId,
    this.memberToken,
    this.api,
  });
  final Map<String, dynamic> bill;
  final String token;
  final String? tabId;
  final String? memberToken;
  final int? selectedId;
  final ValueChanged<int>? onSelected;
  final Future<void> Function() onChanged;
  final ApiService? api;
  @override
  State<ParticipantIdentityPanel> createState() =>
      _ParticipantIdentityPanelState();
}

class _ParticipantIdentityPanelState extends State<ParticipantIdentityPanel> {
  late final _api = widget.api ?? ApiService();
  MemberIdentity? _member;
  bool _busy = false;
  String? _error;
  Future<void> Function()? _retry;
  final _label = TextEditingController();
  final _source = TextEditingController();
  ({String ref, String label, int revision})? _creation;
  @override
  void initState() {
    super.initState();
    _recover();
  }

  Future<void> _recover() async {
    try {
      if (widget.tabId != null && widget.memberToken != null) {
        final me = await _api.getCurrentMember(
          int.parse(widget.tabId!),
          widget.token,
          widget.memberToken!,
        );
        if (mounted) setState(() => _member = me);
      }
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('participant_v2_${widget.bill['id']}');
      if (raw == null) {
        return;
      }
      final saved = jsonDecode(raw);
      final current = BillIdentity.fromJson(widget.bill);
      if (saved is Map &&
          saved['version'] == 2 &&
          saved['bill_id'] == current.id &&
          current.participants.any((p) => p.id == saved['participant_id'])) {
        widget.onSelected?.call(saved['participant_id'] as int);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error =
                  'Stored membership or selection could not be verified. Recover the existing membership; a label cannot replace it.',
        );
      }
    }
  }

  @override
  void dispose() {
    _label.dispose();
    _source.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      _retry = null;
      if (mounted) {
        await widget.onChanged();
      }
    } catch (e) {
      _retry = action;
      if (mounted) {
        await widget.onChanged();
      }
      if (mounted) {
        setState(
          () =>
              _error =
                  e is ApiException
                      ? e.message
                      : 'Identity action unavailable. Refresh and review before retrying.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _select(int id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'participant_v2_${widget.bill['id']}',
      jsonEncode({
        'version': 2,
        'bill_id': widget.bill['id'],
        'participant_id': id,
      }),
    );
    if (mounted) {
      widget.onSelected?.call(id);
    }
  }

  Future<void> _command({
    int? id,
    String? label,
    String? ref,
    bool request = false,
    String? decision,
    int? target,
    int? generation,
    int? revision,
  }) async {
    final result = await _api.participantCommand(
      billId: '${widget.bill['id']}',
      token: widget.token,
      tabId: widget.tabId,
      memberToken: widget.memberToken,
      participantId: id,
      label: label,
      clientRef: ref,
      bindingRequest: request,
      expectedRevision: revision ?? widget.bill['identity_revision'] as int,
      decision: decision,
      memberId: target,
      requestRevision: generation,
      billToken: _source.text.isEmpty ? null : _source.text,
    );
    if (ref != null) {
      await _select(result.participant.id);
      _creation = null;
    }
  }

  Future<void> _rename(ParticipantIdentity p) async {
    final revision = widget.bill['identity_revision'] as int;
    final label = await showDialog<String>(
      context: context,
      builder:
          (_) => _ParticipantLabelDialog(
            title: 'Rename ${p.displayLabel}',
            initialLabel: p.label,
          ),
    );
    if (label != null && mounted) {
      await _run(() => _command(id: p.id, label: label, revision: revision));
    }
  }

  @override
  Widget build(BuildContext context) {
    BillIdentity current;
    try {
      current = BillIdentity.fromJson(widget.bill);
    } catch (_) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Recorded history; participant identity needs review.'),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Receipt participants',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (!current.ready)
              const Text(
                'Recorded history; ownership needs review. Identity edits are unavailable.',
              ),
            for (final p in current.participants)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    selected: widget.selectedId == p.id,
                    title: Text(p.displayLabel),
                    subtitle: Text(
                      '${p.bindingState}${p.memberId == null ? '' : ' · member #${p.memberId}'}${p.pendingMemberId == null ? '' : ' · member #${p.pendingMemberId} requested'}',
                    ),
                    onTap:
                        !current.ready || _busy || widget.onSelected == null
                            ? null
                            : () => _select(p.id),
                  ),
                  if (current.ready)
                    Wrap(
                      spacing: 8,
                      children: [
                        if (widget.tabId == null ||
                            _member?.role == 'creator' ||
                            p.memberId != null &&
                                p.memberId == _member?.memberId ||
                            _source.text.isNotEmpty)
                          TextButton(
                            onPressed: _busy ? null : () => _rename(p),
                            child: const Text('Rename'),
                          ),
                        if (widget.tabId != null &&
                            _member != null &&
                            p.bindingState == 'unbound')
                          TextButton(
                            onPressed:
                                _busy
                                    ? null
                                    : () {
                                      final revision = current.revision;
                                      _run(
                                        () => _command(
                                          id: p.id,
                                          request: true,
                                          revision: revision,
                                        ),
                                      );
                                    },
                            child: const Text('Request my binding'),
                          ),
                        if (p.bindingState == 'pending' &&
                            (_member?.role == 'creator' ||
                                _source.text.isNotEmpty))
                          for (final decision in ['approve', 'reject'])
                            TextButton(
                              onPressed:
                                  _busy
                                      ? null
                                      : () {
                                        final revision = current.revision;
                                        _run(
                                          () => _command(
                                            id: p.id,
                                            decision: decision,
                                            target: p.pendingMemberId,
                                            generation: p.requestRevision,
                                            revision: revision,
                                          ),
                                        );
                                      },
                              child: Text(
                                '$decision request #${p.requestRevision}',
                              ),
                            ),
                      ],
                    ),
                ],
              ),
            if (current.ready) ...[
              TextField(
                controller: _label,
                enabled: !_busy && _creation == null,
                decoration: const InputDecoration(
                  labelText: 'New occurrence label (optional)',
                ),
              ),
              TextButton(
                onPressed:
                    _busy
                        ? null
                        : () {
                          final op =
                              _creation ??= (
                                ref: Person.newClientRef(),
                                label: _label.text,
                                revision: current.revision,
                              );
                          _run(
                            () => _command(
                              label: op.label,
                              ref: op.ref,
                              revision: op.revision,
                            ),
                          );
                        },
                child: const Text('Add occurrence'),
              ),
            ],
            if (widget.tabId != null)
              TextField(
                controller: _source,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Source bill capability for approval (optional)',
                ),
              ),
            if (widget.tabId != null &&
                _member != null &&
                widget.memberToken != null)
              TextButton(
                onPressed:
                    _busy
                        ? null
                        : () async {
                          final label = await showDialog<String>(
                            context: context,
                            builder:
                                (_) => _ParticipantLabelDialog(
                                  title: 'My tab label',
                                  initialLabel: _member!.label,
                                ),
                          );
                          if (label != null) {
                            await _run(() async {
                              final me = await _api.renameCurrentMember(
                                int.parse(widget.tabId!),
                                widget.token,
                                widget.memberToken!,
                                label,
                              );
                              if (mounted) setState(() => _member = me);
                            });
                          }
                        },
                child: const Text('Rename my tab label'),
              ),
            const Text(
              'Labels do not prove ownership. Pending requests cannot mark a share paid.',
            ),
            if (_error != null)
              Semantics(liveRegion: true, child: Text(_error!)),
            if (_retry != null)
              TextButton(
                onPressed: _busy ? null : () => _run(_retry!),
                child: const Text('Retry original action after review'),
              ),
          ],
        ),
      ),
    );
  }
}

class _ParticipantLabelDialog extends StatefulWidget {
  const _ParticipantLabelDialog({
    required this.title,
    required this.initialLabel,
  });
  final String title;
  final String initialLabel;
  @override
  State<_ParticipantLabelDialog> createState() =>
      _ParticipantLabelDialogState();
}

class _ParticipantLabelDialogState extends State<_ParticipantLabelDialog> {
  late final _controller = TextEditingController(text: widget.initialLabel);
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _controller,
      decoration: const InputDecoration(labelText: 'Label (optional)'),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _controller.text),
        child: const Text('Rename'),
      ),
    ],
  );
}
