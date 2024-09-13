SELECT
    CASE
        WHEN o.object_type = 'database' THEN 'DATABASE'
        WHEN o.object_type = 'role' THEN 'USER'
        WHEN o.object_type = 'schema' THEN 'SCHEMA'
        WHEN o.object_type = 'tablespace' THEN 'TABLESPACE'
        WHEN o.object_type = 'table' THEN 'TABLE'
        WHEN o.object_type = 'column' THEN 'COLUMN'
        WHEN o.object_type = 'index' THEN 'INDEX'
        WHEN o.object_type = 'constraint' THEN 'CONSTRAINT'
        WHEN o.object_type = 'function' THEN 'FUNCTION'
        WHEN o.object_type = 'procedure' THEN 'PROCEDURE'
        WHEN o.object_type = 'trigger' THEN 'TRIGGER'
        WHEN o.object_type = 'session' THEN 'SESSION'
        WHEN o.object_type = 'composite_type' THEN 'COMPOSITE TYPE'
        ELSE o.object_type
    END AS object_type,
    o.object_schema,
    o.object_name,
    o.object_owner,
    o.object_definition
FROM (
    -- Previous queries remain the same
    -- ... (include all previous UNION ALL clauses)

    UNION ALL
    -- Composite Types
    SELECT 'composite_type', n.nspname, t.typname, pg_get_userbyid(t.typowner),
           (SELECT string_agg(a.attname || ' ' || pg_catalog.format_type(a.atttypid, a.atttypmod), ', ')
            FROM pg_attribute a
            WHERE a.attrelid = t.typrelid AND a.attnum > 0 AND NOT a.attisdropped)
    FROM pg_type t
    JOIN pg_namespace n ON n.oid = t.typnamespace
    WHERE t.typtype = 'c'
) o
ORDER BY o.object_type, o.object_schema, o.object_name;
