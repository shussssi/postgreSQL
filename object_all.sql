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
        ELSE o.object_type
    END AS object_type,
    o.object_schema,
    o.object_name,
    o.object_owner,
    o.object_definition
FROM (
    -- Databases
    SELECT 'database' AS object_type, NULL AS object_schema, datname AS object_name, 
           pg_get_userbyid(datdba) AS object_owner, NULL AS object_definition
    FROM pg_database
    UNION ALL
    -- Users (Roles)
    SELECT 'role', NULL, rolname, NULL, NULL
    FROM pg_roles
    UNION ALL
    -- Schemas
    SELECT 'schema', NULL, nspname, pg_get_userbyid(nspowner), NULL
    FROM pg_namespace
    UNION ALL
    -- Tablespaces
    SELECT 'tablespace', NULL, spcname, pg_get_userbyid(spcowner), NULL
    FROM pg_tablespace
    UNION ALL
    -- Tables and their columns
    SELECT 'table', n.nspname, c.relname, pg_get_userbyid(c.relowner), NULL
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE c.relkind = 'r'
    UNION ALL
    SELECT 'column', n.nspname, c.relname || '.' || a.attname, pg_get_userbyid(c.relowner), 
           pg_catalog.format_type(a.atttypid, a.atttypmod)
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    JOIN pg_attribute a ON a.attrelid = c.oid
    WHERE c.relkind = 'r' AND a.attnum > 0 AND NOT a.attisdropped
    UNION ALL
    -- Indexes
    SELECT 'index', n.nspname, c.relname, pg_get_userbyid(c.relowner), pg_get_indexdef(c.oid)
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE c.relkind = 'i'
    UNION ALL
    -- Constraints (including Primary Keys)
    SELECT 'constraint', n.nspname, con.conname, pg_get_userbyid(c.relowner), pg_get_constraintdef(con.oid)
    FROM pg_constraint con
    JOIN pg_class c ON c.oid = con.conrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    UNION ALL
    -- Functions and Procedures
    SELECT CASE WHEN p.prokind = 'f' THEN 'function' ELSE 'procedure' END,
           n.nspname, p.proname, pg_get_userbyid(p.proowner), pg_get_functiondef(p.oid)
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE p.prokind IN ('f', 'p')
    UNION ALL
    -- Triggers
    SELECT 'trigger', n.nspname, t.tgname, pg_get_userbyid(c.relowner), pg_get_triggerdef(t.oid)
    FROM pg_trigger t
    JOIN pg_class c ON c.oid = t.tgrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE NOT t.tgisinternal
    UNION ALL
    -- Sessions
    SELECT 'session', NULL, application_name, usename, query
    FROM pg_stat_activity
    WHERE datname = current_database()
) o
ORDER BY o.object_type, o.object_schema, o.object_name;
