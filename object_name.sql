SELECT DISTINCT
    CASE
        WHEN object_type = 'database' THEN 'DATABASE'
        WHEN object_type = 'role' THEN 'USER'
        WHEN object_type = 'schema' THEN 'SCHEMA'
        WHEN object_type = 'tablespace' THEN 'TABLESPACE'
        WHEN object_type = 'table' THEN 'TABLE'
        WHEN object_type = 'column' THEN 'COLUMN'
        WHEN object_type = 'index' THEN 'INDEX'
        WHEN object_type = 'constraint' THEN 'CONSTRAINT'
        WHEN object_type = 'function' THEN 'FUNCTION'
        WHEN object_type = 'procedure' THEN 'PROCEDURE'
        WHEN object_type = 'trigger' THEN 'TRIGGER'
        WHEN object_type = 'session' THEN 'SESSION'
        ELSE object_type
    END AS object_type
FROM (
    SELECT 'database' AS object_type FROM pg_database
    UNION ALL
    SELECT 'role' FROM pg_roles
    UNION ALL
    SELECT 'schema' FROM pg_namespace
    UNION ALL
    SELECT 'tablespace' FROM pg_tablespace
    UNION ALL
    SELECT 'table' FROM pg_class WHERE relkind = 'r'
    UNION ALL
    SELECT 'column' FROM pg_attribute WHERE attnum > 0 AND NOT attisdropped
    UNION ALL
    SELECT 'index' FROM pg_class WHERE relkind = 'i'
    UNION ALL
    SELECT 'constraint' FROM pg_constraint
    UNION ALL
    SELECT CASE WHEN prokind = 'f' THEN 'function' ELSE 'procedure' END
    FROM pg_proc WHERE prokind IN ('f', 'p')
    UNION ALL
    SELECT 'trigger' FROM pg_trigger WHERE NOT tgisinternal
    UNION ALL
    SELECT 'session' FROM pg_stat_activity WHERE datname = current_database()
) AS subquery
ORDER BY object_type;
