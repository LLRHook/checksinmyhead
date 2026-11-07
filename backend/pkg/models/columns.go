package models

// Complete, stable storage shapes keep warmed PostgreSQL prepared statements
// valid across additive DDL. Never replace these with SELECT * or omit a field
// that affects authorization, immutable accounting, or snapshot evidence.
const BillColumns = "id,lazy_mode,tab_id,added_by_member_id,paid_by_member_id,name,subtotal,tax,tip_amount,tip_percentage,total,currency_code,usd_exchange_rate,usd_total,display_currency,display_total,exchange_rate,exchange_rate_source,exchange_rate_date,creation_key_digest,creation_fingerprint,creation_fingerprint_version,display_rate_date,display_rate_source,display_rate_retrieved_at,date,payment_methods,access_token,created_at,updated_at,identity_version,identity_state,identity_revision,creation_response_version,creation_response"
const ParticipantColumns = "id,bill_id,person_id,label,allocation_label,identity_version,ordinal,client_ref,tab_id,member_id,pending_member_id,approved_by_member_id,approval_kind,requested_at,approved_at,pending_request_revision,last_binding_member_id,last_binding_request_revision,last_binding_decision,last_binding_actor_member_id,last_binding_actor_kind,last_binding_result_revision,last_binding_decided_at"
const ItemColumns = "id,bill_id,name,price,created_at,updated_at"
const AssignmentColumns = "id,bill_item_id,person_name,percentage,created_at,updated_at,identity_version,participant_id,bill_id"
const ShareColumns = "id,bill_id,person_name,items,subtotal,tax_share,tip_share,total,paid,identity_version,participant_id"
const TabColumns = "id,name,description,display_currency,finalized,finalized_at,access_token,created_at,updated_at"
const MemberColumns = "id,tab_id,display_name,member_token,role,joined_at"
const SettlementColumns = "id,tab_id,person_name,amount,paid,created_at,snapshot_version,member_id,participant_id"
