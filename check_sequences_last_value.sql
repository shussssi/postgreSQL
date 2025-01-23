\set ON_ERROR_STOP on

-- 冒頭でメッセージを出す (\echo ではなく SELECT を使用)
SELECT '==========================================' AS info
UNION ALL
SELECT '[INFO] シーケンス動作チェック (last_value) 開始'
UNION ALL
SELECT 'SELECT last_value FROM schema.sequence でエラーが出ないか確認'
UNION ALL
SELECT '※ シーケンスはインクリメントしません。'
UNION ALL
SELECT '==========================================';

DO $$
DECLARE
    rec    record;
    seq_sql text;
BEGIN
    -- シーケンス (relkind = 'S') を列挙
    FOR rec IN
        SELECT c.relname AS seq_name,
               n.nspname AS schema_name
          FROM pg_class c
          JOIN pg_namespace n ON c.relnamespace = n.oid
         WHERE c.relkind = 'S'
           AND n.nspname NOT IN ('pg_catalog','information_schema')
           AND c.relname NOT LIKE 'pg_%'
         ORDER BY n.nspname, c.relname
    LOOP
        -- シーケンス名を表示
        RAISE NOTICE 'Checking sequence: %.%', rec.schema_name, rec.seq_name;

        -- last_value を参照するSQLを作成
        seq_sql := format('SELECT last_value FROM %I.%I;', rec.schema_name, rec.seq_name);

        RAISE NOTICE 'Exec: %', seq_sql;

        BEGIN
            EXECUTE seq_sql;  -- 実際にSELECTする
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE 'Error checking sequence %.%: %',
                         rec.schema_name, rec.seq_name, SQLERRM;
        END;
    END LOOP;

    -- 終了メッセージ
    RAISE NOTICE '==========================================';
    RAISE NOTICE '[INFO] シーケンス(last_value) スモークテスト終了';
    RAISE NOTICE '==========================================';
END
$$;
