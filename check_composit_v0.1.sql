\set ON_ERROR_STOP on

-- 最初にメッセージを表示（\echo ではなく SELECT を利用）
SELECT '==========================================' AS info
UNION ALL
SELECT '[INFO] 複合型 (composite type) スモークテスト開始'
UNION ALL
SELECT 'NULL::複合型 でキャストしてみるだけの簡易チェック'
UNION ALL
SELECT '==========================================';

DO $$
DECLARE
    rec record;
    v_sql text;
BEGIN
    FOR rec IN
        SELECT n.nspname AS schema_name,
               t.typname AS type_name
          FROM pg_type t
          JOIN pg_namespace n ON t.typnamespace = n.oid
         WHERE t.typtype = 'c'  -- 'c' = composite
           AND n.nspname NOT IN ('pg_catalog','information_schema')
           AND t.typname NOT LIKE 'pg_%'
         ORDER BY n.nspname, t.typname
    LOOP
        RAISE NOTICE 'Checking composite type: %.%', rec.schema_name, rec.type_name;

        -- 単純に NULL を複合型にキャストしてみるテスト。
        v_sql := format('SELECT NULL::%I.%I;', rec.schema_name, rec.type_name);
        RAISE NOTICE 'Exec: %', v_sql;

        BEGIN
            EXECUTE v_sql;
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE 'Error using composite type %.%: %',
                         rec.schema_name, rec.type_name, SQLERRM;
        END;
    END LOOP;

    RAISE NOTICE '==========================================';
    RAISE NOTICE '[INFO] 複合型スモークテスト終了';
    RAISE NOTICE '==========================================';
END
$$;
