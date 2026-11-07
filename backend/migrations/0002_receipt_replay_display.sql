ALTER TABLE bills
ADD COLUMN creation_key_digest bytea,
ADD COLUMN creation_fingerprint bytea,
ADD COLUMN creation_fingerprint_version smallint,
ADD COLUMN display_rate_date varchar(10),
ADD COLUMN display_rate_source text,
ADD COLUMN display_rate_retrieved_at timestamptz,
ADD CONSTRAINT bills_creation_replay_shape CHECK (
(creation_key_digest IS NULL AND creation_fingerprint IS NULL AND creation_fingerprint_version IS NULL) OR (creation_key_digest IS NOT NULL AND creation_fingerprint IS NOT NULL AND creation_fingerprint_version IS NOT NULL AND octet_length(creation_key_digest)=32 AND octet_length(creation_fingerprint)=32 AND creation_fingerprint_version>0)),
ADD CONSTRAINT bills_display_rate_shape CHECK ((
(display_rate_date IS NULL AND display_rate_source IS NULL
AND display_rate_retrieved_at IS NULL) OR
(display_rate_source='same_currency' AND display_rate_date IS NULL
AND display_rate_retrieved_at IS NULL AND currency_code=display_currency
AND display_total IS NOT NULL AND display_total=total
AND (exchange_rate IS NULL OR exchange_rate=1)) OR
(display_rate_source IS NOT NULL AND display_rate_source<>'same_currency'
AND display_rate_source=btrim(display_rate_source)
AND octet_length(display_rate_source) BETWEEN 1 AND 64
AND currency_code<>display_currency AND display_rate_date IS NOT NULL
AND display_rate_date ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
AND display_rate_retrieved_at IS NOT NULL
AND isfinite(display_rate_retrieved_at)
AND exchange_rate IS NOT NULL AND exchange_rate>0
AND exchange_rate<'Infinity'::numeric AND display_total IS NOT NULL)
) IS TRUE);
CREATE UNIQUE INDEX idx_bills_creation_key_digest
ON bills USING btree (creation_key_digest);
