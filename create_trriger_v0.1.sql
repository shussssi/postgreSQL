\set ON_ERROR_STOP on

SELECT '==========================================' AS info
UNION ALL
SELECT '[INFO] トリガー スモークテスト開始'
UNION ALL
SELECT '簡易的に INSERT/UPDATE/DELETE を試してみる (ROLLBACKする)'
UNION ALL
SELECT 'テーブル構造やトリガー内容によっては失敗する場合があります。'
UNION ALL
SELECT '==========================================';

DO $$
DECLARE
    rec record;
    tblname text;
    v_sql   text;
BEGIN
    /*
      pg_trigger からユーザー定義トリガーを列挙。
       - システムトリガー(tgname ~ '^pg_') は除外
       - テーブル名は tgrelid -> pg_class で取得
       - relkind in ('r','p','f') など「更新可能なテーブル」を対象にしたほうがよい
    */
    FOR rec IN
        SELECT t.tgname,
               t.tgrelid,
               c.relname,
               n.nspname
          FROM pg_trigger t
          JOIN pg_class c ON t.tgrelid = c.oid
          JOIN pg_namespace n ON c.relnamespace = n.oid
         WHERE n.nspname NOT IN ('pg_catalog','information_schema')
           AND c.relkind IN ('r','p','f')  -- 通常テーブル/パーティション/外部テーブル等
           AND t.tgname NOT LIKE 'pg_%'    -- システムトリガーを除外
         ORDER BY n.nspname, c.relname, t.tgname
    LOOP
        RAISE NOTICE 'Trigger found: %.% => %', rec.nspname, rec.relname, rec.tgname;

        tblname := format('%I.%I', rec.nspname, rec.relname);

        /*
          簡易チェック方法 (例):
            BEGIN;
              INSERT INTO table DEFAULT VALUES;
              UPDATE table SET dummy = dummy; -- or something minimal
              DELETE FROM table WHERE 条件 LIMIT 1;
            ROLLBACK;
          
          ただし、テーブル構造によっては NOT NULL カラムがある / デフォルトがない
          / FK制約がある / etc. で失敗する可能性あり
          
          また、トリガーが "DELETE ONLY" の場合は INSERT/UPDATE では発火しないなど、
          全ケースを網羅できるわけではありません。
        */

        v_sql := format($$
        BEGIN;
          INSERT INTO %s DEFAULT VALUES;
          UPDATE %s SET xmin = xmin LIMIT 1; -- xmin=xmin はダミー更新
          DELETE FROM %s WHERE TRUE LIMIT 1;
        ROLLBACK;
        $$, tblname, tblname, tblname);

        RAISE NOTICE 'Exec: %', v_sql;

        BEGIN
            EXECUTE v_sql;
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE 'Error testing trigger on table %.%: %',
                         rec.nspname, rec.relname, SQLERRM;
        END;
    END LOOP;

    RAISE NOTICE '==========================================';
    RAISE NOTICE '[INFO] トリガースモークテスト終了';
    RAISE NOTICE '==========================================';
END
$$;
