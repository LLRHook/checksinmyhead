-- Additive identity foundation only. Existing and default writes stay graph1/review.
-- Structural IDs/ordinals are not evidence of historical ownership or rounding ties.
ALTER TABLE bills
    ADD COLUMN identity_version smallint NOT NULL DEFAULT 1,
    ADD COLUMN identity_state text NOT NULL DEFAULT 'legacy_review',
    ADD COLUMN identity_revision bigint NOT NULL DEFAULT 0,
    ADD COLUMN creation_response_version smallint,
    ADD COLUMN creation_response bytea,
    ADD CONSTRAINT bills_identity_shape CHECK (
        ((identity_version=1 AND identity_state='legacy_review') OR
         (identity_version=2 AND identity_state='ready')) IS TRUE),
    ADD CONSTRAINT bills_identity_revision CHECK (identity_revision>=0),
    ADD CONSTRAINT bills_creation_response_shape CHECK ((
        (creation_response_version IS NULL AND creation_response IS NULL) OR
        (creation_response_version IS NOT NULL AND creation_response_version=2 AND
         creation_response IS NOT NULL AND octet_length(creation_response) BETWEEN 1 AND 65536)
    ) IS TRUE),
    ADD CONSTRAINT bills_id_tab_unique UNIQUE (id,tab_id);
ALTER TABLE tab_members ADD CONSTRAINT tab_members_id_tab_unique UNIQUE (id,tab_id);
ALTER TABLE bill_items ADD CONSTRAINT bill_items_id_bill_unique UNIQUE (id,bill_id);

ALTER TABLE bill_participants
    ADD COLUMN id bigserial NOT NULL,
    ADD COLUMN label text NOT NULL DEFAULT '',
    ADD COLUMN allocation_label text NOT NULL DEFAULT '',
    ADD COLUMN identity_version smallint NOT NULL DEFAULT 1,
    ADD COLUMN ordinal bigint,
    ADD COLUMN client_ref varchar(64),
    ADD COLUMN tab_id bigint,
    ADD COLUMN member_id bigint,
    ADD COLUMN pending_member_id bigint,
    ADD COLUMN approved_by_member_id bigint,
    ADD COLUMN approval_kind text,
    ADD COLUMN requested_at timestamptz,
    ADD COLUMN approved_at timestamptz,
    ADD COLUMN pending_request_revision bigint,
    ADD COLUMN last_binding_member_id bigint,
    ADD COLUMN last_binding_request_revision bigint,
    ADD COLUMN last_binding_decision text,
    ADD COLUMN last_binding_actor_member_id bigint,
    ADD COLUMN last_binding_actor_kind text,
    ADD COLUMN last_binding_result_revision bigint,
    ADD COLUMN last_binding_decided_at timestamptz,
    ADD CONSTRAINT bill_participants_id_unique UNIQUE (id),
    ADD CONSTRAINT bill_participants_id_bill_unique UNIQUE (id,bill_id),
    ADD CONSTRAINT bill_participants_id_tab_unique UNIQUE (id,tab_id),
    ADD CONSTRAINT bill_participants_identity_shape CHECK ((
        identity_version=1 OR (identity_version=2 AND ordinal IS NOT NULL AND ordinal>=0
        AND char_length(label)<=30 AND char_length(allocation_label)<=30)
    ) IS TRUE),
    ADD CONSTRAINT bill_participants_client_ref_shape CHECK (
        client_ref IS NULL OR client_ref COLLATE "C" ~ '^[A-Za-z0-9_-]{1,64}$'),
    ADD CONSTRAINT bill_participants_authority_scope CHECK ((
        (member_id IS NULL AND pending_member_id IS NULL AND approved_by_member_id IS NULL
         AND approval_kind IS NULL AND requested_at IS NULL AND approved_at IS NULL
         AND pending_request_revision IS NULL AND last_binding_member_id IS NULL
         AND last_binding_request_revision IS NULL AND last_binding_decision IS NULL
         AND last_binding_actor_member_id IS NULL AND last_binding_actor_kind IS NULL
         AND last_binding_result_revision IS NULL AND last_binding_decided_at IS NULL) OR
        (identity_version=2 AND tab_id IS NOT NULL)
    ) IS TRUE),
    ADD CONSTRAINT bill_participants_pending_shape CHECK ((
        (pending_member_id IS NULL AND requested_at IS NULL AND pending_request_revision IS NULL) OR
        (pending_member_id IS NOT NULL AND requested_at IS NOT NULL
         AND pending_request_revision IS NOT NULL AND pending_request_revision>0)
    ) IS TRUE),
    ADD CONSTRAINT bill_participants_binding_shape CHECK ((
        (member_id IS NULL AND approved_by_member_id IS NULL AND approval_kind IS NULL AND approved_at IS NULL) OR
        (member_id IS NOT NULL AND approved_by_member_id IS NOT NULL
         AND approval_kind IS NOT NULL AND approval_kind IN ('creator','source') AND approved_at IS NOT NULL
         AND pending_member_id IS NULL AND requested_at IS NULL AND pending_request_revision IS NULL)
    ) IS TRUE),
    ADD CONSTRAINT bill_participants_receipt_shape CHECK ((
        (last_binding_member_id IS NULL AND last_binding_request_revision IS NULL
         AND last_binding_decision IS NULL AND last_binding_actor_member_id IS NULL
         AND last_binding_actor_kind IS NULL AND last_binding_result_revision IS NULL
         AND last_binding_decided_at IS NULL) OR
        (last_binding_member_id IS NOT NULL AND last_binding_request_revision IS NOT NULL
         AND last_binding_request_revision>0 AND last_binding_decision IS NOT NULL
         AND last_binding_decision IN ('approve','reject') AND last_binding_actor_member_id IS NOT NULL
         AND last_binding_actor_kind IS NOT NULL AND last_binding_actor_kind IN ('creator','source')
         AND last_binding_result_revision IS NOT NULL
         AND last_binding_result_revision>last_binding_request_revision AND last_binding_decided_at IS NOT NULL)
    ) IS TRUE),
    ADD CONSTRAINT bill_participants_bill_tab_fk FOREIGN KEY (bill_id,tab_id)
        REFERENCES bills(id,tab_id) MATCH SIMPLE ON UPDATE RESTRICT ON DELETE RESTRICT NOT DEFERRABLE,
    ADD CONSTRAINT bill_participants_member_tab_fk FOREIGN KEY (member_id,tab_id)
        REFERENCES tab_members(id,tab_id) MATCH SIMPLE ON UPDATE RESTRICT ON DELETE RESTRICT NOT DEFERRABLE,
    ADD CONSTRAINT bill_participants_pending_tab_fk FOREIGN KEY (pending_member_id,tab_id)
        REFERENCES tab_members(id,tab_id) MATCH SIMPLE ON UPDATE RESTRICT ON DELETE RESTRICT NOT DEFERRABLE,
    ADD CONSTRAINT bill_participants_approver_tab_fk FOREIGN KEY (approved_by_member_id,tab_id)
        REFERENCES tab_members(id,tab_id) MATCH SIMPLE ON UPDATE RESTRICT ON DELETE RESTRICT NOT DEFERRABLE,
    ADD CONSTRAINT bill_participants_receipt_member_tab_fk FOREIGN KEY (last_binding_member_id,tab_id)
        REFERENCES tab_members(id,tab_id) MATCH SIMPLE ON UPDATE RESTRICT ON DELETE RESTRICT NOT DEFERRABLE,
    ADD CONSTRAINT bill_participants_receipt_actor_tab_fk FOREIGN KEY (last_binding_actor_member_id,tab_id)
        REFERENCES tab_members(id,tab_id) MATCH SIMPLE ON UPDATE RESTRICT ON DELETE RESTRICT NOT DEFERRABLE;
CREATE UNIQUE INDEX idx_bill_participants_client_ref ON bill_participants(bill_id,client_ref) WHERE client_ref IS NOT NULL;
CREATE UNIQUE INDEX idx_bill_participants_ordinal ON bill_participants(bill_id,ordinal) WHERE ordinal IS NOT NULL;
CREATE UNIQUE INDEX idx_bill_participants_member ON bill_participants(bill_id,member_id) WHERE member_id IS NOT NULL;
CREATE UNIQUE INDEX idx_bill_participants_pending ON bill_participants(bill_id,pending_member_id) WHERE pending_member_id IS NOT NULL;
CREATE INDEX idx_bill_participants_bill_tab ON bill_participants(bill_id,tab_id);
CREATE INDEX idx_bill_participants_member_tab ON bill_participants(member_id,tab_id);
CREATE INDEX idx_bill_participants_pending_tab ON bill_participants(pending_member_id,tab_id);
CREATE INDEX idx_bill_participants_approver_tab ON bill_participants(approved_by_member_id,tab_id);
CREATE INDEX idx_bill_participants_receipt_member_tab ON bill_participants(last_binding_member_id,tab_id);
CREATE INDEX idx_bill_participants_receipt_actor_tab ON bill_participants(last_binding_actor_member_id,tab_id);

-- Preserve exact labels, including empty/long/colliding legacy values. No binding.
WITH structural AS (
    SELECT p.bill_id,p.person_id,person.name,b.tab_id,
           row_number() OVER (PARTITION BY p.bill_id ORDER BY p.person_id)-1 AS ordinal
    FROM bill_participants p JOIN people person ON person.id=p.person_id JOIN bills b ON b.id=p.bill_id
)
UPDATE bill_participants p SET label=s.name,allocation_label=s.name,ordinal=s.ordinal,tab_id=s.tab_id
FROM structural s WHERE p.bill_id=s.bill_id AND p.person_id=s.person_id;

ALTER TABLE item_assignments
    ADD COLUMN identity_version smallint NOT NULL DEFAULT 1,
    ADD COLUMN participant_id bigint,
    ADD COLUMN bill_id bigint,
    ADD CONSTRAINT item_assignments_identity_shape CHECK ((
        (identity_version=1 AND participant_id IS NULL) OR
        (identity_version=2 AND participant_id IS NOT NULL AND bill_id IS NOT NULL)
    ) IS TRUE),
    ADD CONSTRAINT item_assignments_item_bill_fk FOREIGN KEY (bill_item_id,bill_id)
        REFERENCES bill_items(id,bill_id) MATCH SIMPLE ON UPDATE RESTRICT ON DELETE RESTRICT NOT DEFERRABLE,
    ADD CONSTRAINT item_assignments_participant_bill_fk FOREIGN KEY (participant_id,bill_id)
        REFERENCES bill_participants(id,bill_id) MATCH SIMPLE ON UPDATE RESTRICT ON DELETE RESTRICT NOT DEFERRABLE;
CREATE UNIQUE INDEX idx_item_assignments_participant ON item_assignments(bill_item_id,participant_id) WHERE participant_id IS NOT NULL;
CREATE INDEX idx_item_assignments_item_bill ON item_assignments(bill_item_id,bill_id);
CREATE INDEX idx_item_assignments_participant_bill ON item_assignments(participant_id,bill_id);
UPDATE item_assignments a SET bill_id=i.bill_id FROM bill_items i WHERE i.id=a.bill_item_id;

ALTER TABLE person_shares
    ADD COLUMN identity_version smallint NOT NULL DEFAULT 1,
    ADD COLUMN participant_id bigint,
    ADD CONSTRAINT person_shares_identity_shape CHECK ((
        (identity_version=1 AND participant_id IS NULL) OR
        (identity_version=2 AND participant_id IS NOT NULL)
    ) IS TRUE),
    ADD CONSTRAINT person_shares_participant_bill_fk FOREIGN KEY (participant_id,bill_id)
        REFERENCES bill_participants(id,bill_id) MATCH SIMPLE ON UPDATE RESTRICT ON DELETE RESTRICT NOT DEFERRABLE;
CREATE UNIQUE INDEX idx_person_shares_participant ON person_shares(bill_id,participant_id) WHERE participant_id IS NOT NULL;
CREATE INDEX idx_person_shares_participant_bill ON person_shares(participant_id,bill_id);

ALTER TABLE tab_settlements
    ADD COLUMN snapshot_version smallint NOT NULL DEFAULT 1,
    ADD COLUMN member_id bigint,
    ADD COLUMN participant_id bigint,
    ADD CONSTRAINT tab_settlements_identity_shape CHECK ((
        (snapshot_version=1 AND member_id IS NULL AND participant_id IS NULL) OR
        (snapshot_version=2 AND ((member_id IS NOT NULL AND participant_id IS NULL) OR
                                (member_id IS NULL AND participant_id IS NOT NULL)))
    ) IS TRUE),
    ADD CONSTRAINT tab_settlements_member_tab_fk FOREIGN KEY (member_id,tab_id)
        REFERENCES tab_members(id,tab_id) MATCH SIMPLE ON UPDATE RESTRICT ON DELETE RESTRICT NOT DEFERRABLE,
    ADD CONSTRAINT tab_settlements_participant_tab_fk FOREIGN KEY (participant_id,tab_id)
        REFERENCES bill_participants(id,tab_id) MATCH SIMPLE ON UPDATE RESTRICT ON DELETE RESTRICT NOT DEFERRABLE;
CREATE UNIQUE INDEX idx_tab_settlements_member ON tab_settlements(tab_id,member_id) WHERE snapshot_version=2 AND member_id IS NOT NULL;
CREATE UNIQUE INDEX idx_tab_settlements_participant ON tab_settlements(tab_id,participant_id) WHERE snapshot_version=2 AND participant_id IS NOT NULL;
CREATE INDEX idx_tab_settlements_member_tab ON tab_settlements(member_id,tab_id);
CREATE INDEX idx_tab_settlements_participant_tab ON tab_settlements(participant_id,tab_id);
