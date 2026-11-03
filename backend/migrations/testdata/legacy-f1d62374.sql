-- Frozen legacy f1d62374 fixture from driver pg_dump, independent of the runtime registry.
CREATE TABLE bill_items (
    id bigint NOT NULL,
    bill_id bigint NOT NULL,
    name text NOT NULL,
    price numeric NOT NULL,
    created_at timestamp with time zone,
    updated_at timestamp with time zone
);
CREATE SEQUENCE bill_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE bill_items_id_seq OWNED BY bill_items.id;
CREATE TABLE bill_participants (
    bill_id bigint NOT NULL,
    person_id bigint NOT NULL
);
CREATE TABLE bills (
    id bigint NOT NULL,
    lazy_mode boolean DEFAULT false NOT NULL,
    tab_id bigint,
    added_by_member_id bigint,
    paid_by_member_id bigint,
    name text NOT NULL,
    subtotal numeric NOT NULL,
    tax numeric NOT NULL,
    tip_amount numeric NOT NULL,
    tip_percentage numeric,
    total numeric NOT NULL,
    currency_code character(3) DEFAULT 'USD'::bpchar NOT NULL,
    usd_exchange_rate numeric DEFAULT 1 NOT NULL,
    usd_total numeric DEFAULT 0 NOT NULL,
    display_currency character(3) DEFAULT 'USD'::bpchar NOT NULL,
    display_total numeric,
    exchange_rate numeric,
    exchange_rate_source text,
    exchange_rate_date character varying(10),
    date timestamp with time zone NOT NULL,
    payment_methods jsonb,
    access_token character varying(64),
    created_at timestamp with time zone,
    updated_at timestamp with time zone
);
CREATE SEQUENCE bills_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE bills_id_seq OWNED BY bills.id;
CREATE TABLE item_assignments (
    id bigint NOT NULL,
    bill_item_id bigint NOT NULL,
    person_name text NOT NULL,
    percentage numeric NOT NULL,
    created_at timestamp with time zone,
    updated_at timestamp with time zone
);
CREATE SEQUENCE item_assignments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE item_assignments_id_seq OWNED BY item_assignments.id;
CREATE TABLE people (
    id bigint NOT NULL,
    name text NOT NULL
);
CREATE SEQUENCE people_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE people_id_seq OWNED BY people.id;
CREATE TABLE person_shares (
    id bigint NOT NULL,
    bill_id bigint NOT NULL,
    person_name text NOT NULL,
    items jsonb,
    subtotal numeric NOT NULL,
    tax_share numeric NOT NULL,
    tip_share numeric NOT NULL,
    total numeric NOT NULL,
    paid boolean DEFAULT false
);
CREATE SEQUENCE person_shares_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE person_shares_id_seq OWNED BY person_shares.id;
CREATE TABLE tab_members (
    id bigint NOT NULL,
    tab_id bigint NOT NULL,
    display_name text NOT NULL,
    member_token character varying(64),
    role character varying(20) DEFAULT 'member'::character varying,
    joined_at timestamp with time zone
);
CREATE SEQUENCE tab_members_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE tab_members_id_seq OWNED BY tab_members.id;
CREATE TABLE tab_settlements (
    id bigint NOT NULL,
    tab_id bigint NOT NULL,
    person_name text NOT NULL,
    amount numeric NOT NULL,
    paid boolean DEFAULT false,
    created_at timestamp with time zone
);
CREATE SEQUENCE tab_settlements_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE tab_settlements_id_seq OWNED BY tab_settlements.id;
CREATE TABLE tabs (
    id bigint NOT NULL,
    name text NOT NULL,
    description text,
    display_currency character(3) DEFAULT 'USD'::bpchar NOT NULL,
    finalized boolean DEFAULT false,
    finalized_at timestamp with time zone,
    access_token character varying(64),
    created_at timestamp with time zone,
    updated_at timestamp with time zone
);
CREATE SEQUENCE tabs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE tabs_id_seq OWNED BY tabs.id;
ALTER TABLE ONLY bill_items ALTER COLUMN id SET DEFAULT nextval('bill_items_id_seq'::regclass);
ALTER TABLE ONLY bills ALTER COLUMN id SET DEFAULT nextval('bills_id_seq'::regclass);
ALTER TABLE ONLY item_assignments ALTER COLUMN id SET DEFAULT nextval('item_assignments_id_seq'::regclass);
ALTER TABLE ONLY people ALTER COLUMN id SET DEFAULT nextval('people_id_seq'::regclass);
ALTER TABLE ONLY person_shares ALTER COLUMN id SET DEFAULT nextval('person_shares_id_seq'::regclass);
ALTER TABLE ONLY tab_members ALTER COLUMN id SET DEFAULT nextval('tab_members_id_seq'::regclass);
ALTER TABLE ONLY tab_settlements ALTER COLUMN id SET DEFAULT nextval('tab_settlements_id_seq'::regclass);
ALTER TABLE ONLY tabs ALTER COLUMN id SET DEFAULT nextval('tabs_id_seq'::regclass);
ALTER TABLE ONLY bill_items
    ADD CONSTRAINT bill_items_pkey PRIMARY KEY (id);
ALTER TABLE ONLY bill_participants
    ADD CONSTRAINT bill_participants_pkey PRIMARY KEY (bill_id, person_id);
ALTER TABLE ONLY bills
    ADD CONSTRAINT bills_pkey PRIMARY KEY (id);
ALTER TABLE ONLY item_assignments
    ADD CONSTRAINT item_assignments_pkey PRIMARY KEY (id);
ALTER TABLE ONLY people
    ADD CONSTRAINT people_pkey PRIMARY KEY (id);
ALTER TABLE ONLY person_shares
    ADD CONSTRAINT person_shares_pkey PRIMARY KEY (id);
ALTER TABLE ONLY tab_members
    ADD CONSTRAINT tab_members_pkey PRIMARY KEY (id);
ALTER TABLE ONLY tab_settlements
    ADD CONSTRAINT tab_settlements_pkey PRIMARY KEY (id);
ALTER TABLE ONLY tabs
    ADD CONSTRAINT tabs_pkey PRIMARY KEY (id);
CREATE INDEX idx_bill_items_bill_id ON bill_items USING btree (bill_id);
CREATE UNIQUE INDEX idx_bills_access_token ON bills USING btree (access_token);
CREATE INDEX idx_bills_added_by_member_id ON bills USING btree (added_by_member_id);
CREATE INDEX idx_bills_paid_by_member_id ON bills USING btree (paid_by_member_id);
CREATE INDEX idx_bills_tab_id ON bills USING btree (tab_id);
CREATE INDEX idx_item_assignments_bill_item_id ON item_assignments USING btree (bill_item_id);
CREATE INDEX idx_item_assignments_person_name ON item_assignments USING btree (person_name);
CREATE INDEX idx_person_shares_bill_id ON person_shares USING btree (bill_id);
CREATE UNIQUE INDEX idx_tab_members_member_token ON tab_members USING btree (member_token);
CREATE INDEX idx_tab_members_tab_id ON tab_members USING btree (tab_id);
CREATE INDEX idx_tab_settlements_tab_id ON tab_settlements USING btree (tab_id);
CREATE UNIQUE INDEX idx_tabs_access_token ON tabs USING btree (access_token);
ALTER TABLE ONLY item_assignments
    ADD CONSTRAINT fk_bill_items_assignments FOREIGN KEY (bill_item_id) REFERENCES bill_items(id) ON DELETE CASCADE;
ALTER TABLE ONLY bill_participants
    ADD CONSTRAINT fk_bill_participants_bill FOREIGN KEY (bill_id) REFERENCES bills(id) ON DELETE SET NULL;
ALTER TABLE ONLY bill_participants
    ADD CONSTRAINT fk_bill_participants_person FOREIGN KEY (person_id) REFERENCES people(id) ON DELETE SET NULL;
ALTER TABLE ONLY bill_items
    ADD CONSTRAINT fk_bills_items FOREIGN KEY (bill_id) REFERENCES bills(id) ON DELETE CASCADE;
ALTER TABLE ONLY person_shares
    ADD CONSTRAINT fk_bills_person_shares FOREIGN KEY (bill_id) REFERENCES bills(id) ON DELETE CASCADE;
ALTER TABLE ONLY bills
    ADD CONSTRAINT fk_tabs_bills FOREIGN KEY (tab_id) REFERENCES tabs(id);
ALTER TABLE ONLY tab_members
    ADD CONSTRAINT fk_tabs_members FOREIGN KEY (tab_id) REFERENCES tabs(id);
