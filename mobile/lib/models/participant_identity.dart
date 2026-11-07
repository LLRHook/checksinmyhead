/// Current authenticated projections. Stored IDs are selectors, never proof.
class MemberIdentity {
  final int memberId;
  final int tabId;
  final String label;
  final String role;
  MemberIdentity(this.memberId, this.tabId, this.label, this.role);
  factory MemberIdentity.fromJson(Map<String, dynamic> json, int expectedTab) {
    final id = json['member_id'];
    if (id is! int ||
        id <= 0 ||
        json['tab_id'] != expectedTab ||
        json['display_name'] is! String ||
        !['creator', 'member'].contains(json['role'])) {
      throw const FormatException('Invalid scoped member response');
    }
    return MemberIdentity(
      id,
      expectedTab,
      json['display_name'] as String,
      json['role'] as String,
    );
  }
}

class ParticipantIdentity {
  final int id;
  final int billId;
  final String? clientRef;
  final String label;
  final String bindingState;
  final int? memberId;
  final int? pendingMemberId;
  final int? requestRevision;
  ParticipantIdentity.fromJson(Map<String, dynamic> json)
    : id = json['participant_id'] as int,
      billId = json['bill_id'] as int,
      clientRef = json['client_ref'] as String?,
      label = json['label'] as String,
      bindingState = json['binding_state'] as String,
      memberId = json['member_id'] as int?,
      pendingMemberId = json['pending_member_id'] as int?,
      requestRevision = json['pending_request_revision'] as int? {
    if (id <= 0 ||
        billId <= 0 ||
        !['unbound', 'pending', 'confirmed'].contains(bindingState)) {
      throw const FormatException('Invalid participant response');
    }
  }
  String get displayLabel => '${label.isEmpty ? 'Unnamed' : label} · #$id';
  Map<String, dynamic> toJson() => {
    'participant_id': id,
    'bill_id': billId,
    'client_ref': clientRef,
    'label': label,
    'binding_state': bindingState,
    'member_id': memberId,
    'pending_member_id': pendingMemberId,
    'pending_request_revision': requestRevision,
  };
}

class BillIdentity {
  final int id;
  final int revision;
  final int version;
  final String state;
  final String reviewStatus;
  final List<ParticipantIdentity> participants;
  BillIdentity.fromJson(Map<String, dynamic> json)
    : id = json['id'] as int,
      revision = json['identity_revision'] as int,
      version = json['identity_version'] as int,
      state = json['identity_state'] as String,
      reviewStatus = json['identity_review_status'] as String,
      participants =
          (json['participants'] as List)
              .map(
                (p) => ParticipantIdentity.fromJson(p as Map<String, dynamic>),
              )
              .toList() {
    if (id <= 0 ||
        revision < 0 ||
        participants.any((p) => p.billId != id) ||
        participants.map((p) => p.id).toSet().length != participants.length) {
      throw const FormatException('Invalid scoped bill response');
    }
  }
  bool get ready => version == 2 && state == 'ready' && reviewStatus == 'ready';
}

class ParticipantCommandResult {
  final ParticipantIdentity participant;
  final int revision;
  ParticipantCommandResult.fromJson(Map<String, dynamic> json)
    : participant = ParticipantIdentity.fromJson(
        json['participant'] as Map<String, dynamic>,
      ),
      revision = json['identity_revision'] as int;
}
