CREATE TABLE schema_migrations (
    version bigint PRIMARY KEY CHECK (version > 0),
    name text NOT NULL UNIQUE,
    checksum text NOT NULL CHECK (checksum ~ '^[0-9a-f]{64}$'),
    validation_checksum text NOT NULL CHECK (validation_checksum ~ '^[0-9a-f]{64}$'),
    compatibility_epoch bigint NOT NULL CHECK (compatibility_epoch > 0),
    applied_at timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP
);
