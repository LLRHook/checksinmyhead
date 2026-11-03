-- Immutable recognizer v1: PostgreSQL 17 catalogs, not pg_dump text.
WITH relations AS (
  SELECT c.* FROM pg_catalog.pg_class c
  WHERE c.relnamespace = pg_catalog.to_regnamespace($1)
    AND c.relname IN ('bill_items','bill_participants','bills','item_assignments',
      'people','person_shares','tab_members','tab_settlements','tabs','schema_migrations',
      'bill_items_id_seq','bills_id_seq','item_assignments_id_seq','people_id_seq',
      'person_shares_id_seq','tab_members_id_seq','tab_settlements_id_seq','tabs_id_seq')
), objects AS (
  SELECT 'relation/' || c.relname AS key,
    jsonb_build_array(c.relkind, c.relpersistence, c.relrowsecurity, c.relforcerowsecurity,
      c.relispartition, EXISTS(SELECT FROM pg_catalog.pg_inherits WHERE inhrelid=c.oid),
      EXISTS(SELECT FROM pg_catalog.pg_trigger WHERE tgrelid=c.oid AND NOT tgisinternal),
      EXISTS(SELECT FROM pg_catalog.pg_rewrite WHERE ev_class=c.oid),
      EXISTS(SELECT FROM pg_catalog.pg_policy WHERE polrelid=c.oid)) AS value
  FROM relations c
  UNION ALL
  SELECT 'column/' || c.relname || '/' || a.attname,
    jsonb_build_array(tn.nspname, t.typname, a.atttypmod, a.attnotnull,
      a.attidentity, a.attgenerated, cn.nspname, col.collname,
      pg_catalog.pg_get_expr(d.adbin,d.adrelid))
  FROM relations c JOIN pg_catalog.pg_attribute a ON a.attrelid=c.oid AND a.attnum>0 AND NOT a.attisdropped
    JOIN pg_catalog.pg_type t ON t.oid=a.atttypid
    JOIN pg_catalog.pg_namespace tn ON tn.oid=t.typnamespace
    LEFT JOIN pg_catalog.pg_attrdef d ON d.adrelid=c.oid AND d.adnum=a.attnum
    LEFT JOIN pg_catalog.pg_collation col ON col.oid=a.attcollation
    LEFT JOIN pg_catalog.pg_namespace cn ON cn.oid=col.collnamespace
  WHERE c.relkind <> 'S'
  UNION ALL
  SELECT 'constraint/' || c.relname || '/' || con.conname,
    jsonb_build_array(con.contype, con.condeferrable, con.condeferred, con.convalidated,
      ARRAY(SELECT a.attname FROM unnest(con.conkey) WITH ORDINALITY k(num,ord)
        JOIN pg_catalog.pg_attribute a ON a.attrelid=c.oid AND a.attnum=k.num ORDER BY k.ord),
      ref.relname, ref.relnamespace=pg_catalog.to_regnamespace($1),
      ARRAY(SELECT a.attname FROM unnest(con.confkey) WITH ORDINALITY k(num,ord)
        JOIN pg_catalog.pg_attribute a ON a.attrelid=con.confrelid AND a.attnum=k.num ORDER BY k.ord),
      con.confupdtype, con.confdeltype, con.confmatchtype, con.connoinherit,
      pg_catalog.pg_get_expr(con.conbin,con.conrelid))
  FROM relations c JOIN pg_catalog.pg_constraint con ON con.conrelid=c.oid
    LEFT JOIN pg_catalog.pg_class ref ON ref.oid=con.confrelid
  UNION ALL
  SELECT 'index/' || c.relname || '/' || ix.relname,
    jsonb_build_array(am.amname, i.indisunique, i.indisprimary, i.indisexclusion,
      i.indimmediate, i.indisvalid, i.indisready, i.indislive, i.indnullsnotdistinct,
      i.indnkeyatts,
      ARRAY(SELECT a.attname FROM unnest(i.indkey) WITH ORDINALITY k(num,ord)
        LEFT JOIN pg_catalog.pg_attribute a ON a.attrelid=c.oid AND a.attnum=k.num ORDER BY k.ord),
      i.indoption::text,
      ARRAY(SELECT n.nspname || '.' || op.opcname FROM unnest(i.indclass) WITH ORDINALITY k(num,ord)
        JOIN pg_catalog.pg_opclass op ON op.oid=k.num
        JOIN pg_catalog.pg_namespace n ON n.oid=op.opcnamespace ORDER BY k.ord),
      ARRAY(SELECT n.nspname || '.' || co.collname FROM unnest(i.indcollation) WITH ORDINALITY k(num,ord)
        LEFT JOIN pg_catalog.pg_collation co ON co.oid=k.num
        LEFT JOIN pg_catalog.pg_namespace n ON n.oid=co.collnamespace ORDER BY k.ord),
      pg_catalog.pg_get_expr(i.indexprs,c.oid), pg_catalog.pg_get_expr(i.indpred,c.oid))
  FROM relations c JOIN pg_catalog.pg_index i ON i.indrelid=c.oid
    JOIN pg_catalog.pg_class ix ON ix.oid=i.indexrelid
    JOIN pg_catalog.pg_am am ON am.oid=ix.relam
  UNION ALL
  SELECT 'sequence/' || c.relname,
    jsonb_build_array(t.typname,s.seqstart,s.seqincrement,s.seqmax,s.seqmin,s.seqcache,s.seqcycle,
      owner.relname, owner.relnamespace=pg_catalog.to_regnamespace($1), a.attname, d.deptype)
  FROM relations c JOIN pg_catalog.pg_sequence s ON s.seqrelid=c.oid
    JOIN pg_catalog.pg_type t ON t.oid=s.seqtypid
    LEFT JOIN pg_catalog.pg_depend d ON d.classid='pg_catalog.pg_class'::regclass
      AND d.objid=c.oid AND d.refclassid='pg_catalog.pg_class'::regclass AND d.deptype IN ('a','i')
    LEFT JOIN pg_catalog.pg_class owner ON owner.oid=d.refobjid
    LEFT JOIN pg_catalog.pg_attribute a ON a.attrelid=d.refobjid AND a.attnum=d.refobjsubid
)
SELECT key, value FROM objects ORDER BY key
