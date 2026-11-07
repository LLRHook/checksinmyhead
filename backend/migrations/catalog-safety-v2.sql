-- Startup safety guard v2, supplemental to frozen v1/history.
WITH required_relations AS (
 SELECT c.oid FROM pg_catalog.pg_class c
 WHERE c.relnamespace=pg_catalog.to_regnamespace($1)
 AND c.relname IN ('bill_items','bill_participants','bills','item_assignments',
  'people','person_shares','tab_members','tab_settlements','tabs','schema_migrations')
), required_foreign_keys AS (
 SELECT con.oid FROM pg_catalog.pg_constraint con
 WHERE con.contype='f' AND con.conrelid IN (SELECT oid FROM required_relations)
)
SELECT pg_catalog.current_setting('session_replication_role') IN ('origin','local')
 AND NOT EXISTS (
  SELECT FROM pg_catalog.pg_inherits i
  WHERE i.inhrelid IN (SELECT oid FROM required_relations)
     OR i.inhparent IN (SELECT oid FROM required_relations)
 )
 AND NOT EXISTS (
  SELECT fk.oid FROM required_foreign_keys fk
  LEFT JOIN pg_catalog.pg_trigger t ON t.tgconstraint=fk.oid
  GROUP BY fk.oid
  HAVING count(*) FILTER (WHERE t.tgisinternal)<>4
   OR count(*) FILTER (WHERE t.tgisinternal AND t.tgenabled IN ('O','A'))<>4
 ) AS accepted
