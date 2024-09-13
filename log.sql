-- 最初に、ファイル書き込み用の関数を作成します
CREATE OR REPLACE FUNCTION write_to_log(log_message TEXT) RETURNS VOID AS $$
BEGIN
    EXECUTE format('COPY (SELECT %L) TO ''/path/to/output.log'' WITH CSV QUOTE ''"'' DELIMITER '';'' ESCAPE ''\'' ', log_message);
END;
$$ LANGUAGE plpgsql;

-- メインのクエリ
WITH object_info AS (
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
        -- (前回と同じSUBQUERY部分をここに挿入)
    ) o
)
SELECT
    object_type,
    object_schema,
    object_name,
    object_owner,
    object_definition,
    (SELECT CASE
        WHEN object_type = 'DATABASE' THEN 
            write_to_log(format('Database: %s', object_name))
        WHEN object_type = 'USER' THEN 
            write_to_log(format('User: %s', object_name))
        WHEN object_type = 'SCHEMA' THEN 
            write_to_log(format('Schema: %s', object_name))
        WHEN object_type = 'TABLESPACE' THEN 
            write_to_log(format('Tablespace: %s', object_name))
        WHEN object_type = 'TABLE' THEN 
            write_to_log(format('Table: %s.%s', object_schema, object_name))
        WHEN object_type = 'COLUMN' THEN 
            write_to_log(format('Column: %s.%s', object_schema, object_name))
        WHEN object_type = 'INDEX' THEN 
            write_to_log(format('Index: %s.%s', object_schema, object_name))
        WHEN object_type = 'CONSTRAINT' THEN 
            write_to_log(format('Constraint: %s.%s', object_schema, object_name))
        WHEN object_type = 'FUNCTION' THEN 
            write_to_log(format('Function: %s.%s', object_schema, object_name))
        WHEN object_type = 'PROCEDURE' THEN 
            write_to_log(format('Procedure: %s.%s', object_schema, object_name))
        WHEN object_type = 'TRIGGER' THEN 
            write_to_log(format('Trigger: %s.%s', object_schema, object_name))
        WHEN object_type = 'SESSION' THEN 
            write_to_log(format('Session: %s (User: %s)', object_name, object_owner))
        ELSE 
            write_to_log(format('Other object: %s %s.%s', object_type, object_schema, object_name))
    END)
FROM object_info
ORDER BY object_type, object_schema, object_name;
