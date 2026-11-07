-- Supplemental PostgreSQL17 capture: frozen catalog.sql already observes all
-- additions to existing tables, including the participant ID default. Only the
-- new sequence needs its own relation/sequence keys; never duplicate old keys.
WITH relation AS (
    SELECT c.* FROM pg_catalog.pg_class c
    WHERE c.relnamespace=pg_catalog.to_regnamespace($1)
      AND c.relname='bill_participants_id_seq'
), objects AS (
    SELECT 'relation/' || c.relname AS key,
        jsonb_build_array(c.relkind,c.relpersistence,c.relrowsecurity,c.relforcerowsecurity,
            c.relispartition,EXISTS(SELECT FROM pg_catalog.pg_inherits WHERE inhrelid=c.oid),
            EXISTS(SELECT FROM pg_catalog.pg_trigger WHERE tgrelid=c.oid AND NOT tgisinternal),
            EXISTS(SELECT FROM pg_catalog.pg_rewrite WHERE ev_class=c.oid),
            EXISTS(SELECT FROM pg_catalog.pg_policy WHERE polrelid=c.oid)) AS value
    FROM relation c
    UNION ALL
    SELECT 'sequence/' || c.relname,
        jsonb_build_array(t.typname,s.seqstart,s.seqincrement,s.seqmax,s.seqmin,s.seqcache,s.seqcycle,
            owner.relname,owner.relnamespace=pg_catalog.to_regnamespace($1),a.attname,d.deptype)
    FROM relation c JOIN pg_catalog.pg_sequence s ON s.seqrelid=c.oid
        JOIN pg_catalog.pg_type t ON t.oid=s.seqtypid
        LEFT JOIN pg_catalog.pg_depend d ON d.classid='pg_catalog.pg_class'::regclass
            AND d.objid=c.oid AND d.refclassid='pg_catalog.pg_class'::regclass AND d.deptype IN ('a','i')
        LEFT JOIN pg_catalog.pg_class owner ON owner.oid=d.refobjid
        LEFT JOIN pg_catalog.pg_attribute a ON a.attrelid=d.refobjid AND a.attnum=d.refobjsubid
)
SELECT key,value FROM objects ORDER BY key
