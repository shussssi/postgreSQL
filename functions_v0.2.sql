\set ON_ERROR_STOP on

---------------------------------------------------
-- 1. 事前メッセージを表示
---------------------------------------------------
SELECT '==========================================' AS info
UNION ALL
SELECT '[INFO] 引数あり関数も含むスモークテスト開始 (トリガー関数除外)'
UNION ALL
SELECT '引数に NULL や固定値を割り当てて呼び出します。'
UNION ALL
SELECT 'トリガー用に RETURNS trigger / event_trigger な関数は除外します。'
UNION ALL
SELECT '=========================================='
;

---------------------------------------------------
-- 2. サーバサイド DOブロックでスモークテスト
---------------------------------------------------
DO $$
DECLARE
    rec record;
    arg_array text[];
    parsed_arg text;
    argtype   text;
    arg_sql   text;   -- 呼び出しSQLを組み立てる変数
    i         int;
BEGIN

    FOR rec IN
        SELECT p.oid,
               n.nspname AS schema_name,
               p.proname AS function_name,
               pg_catalog.pg_get_function_arguments(p.oid) AS argdef_str,
               p.prokind
          FROM pg_proc p
          JOIN pg_namespace n ON p.pronamespace = n.oid
          JOIN pg_type t ON p.prorettype = t.oid
         WHERE n.nspname NOT IN ('pg_catalog','information_schema')
           AND p.proname NOT LIKE 'pg_%'
           AND p.prokind = 'f'        -- 'f': 普通のFUNCTION (プロシージャ含むならOR条件を追加)
           AND t.typname NOT IN ('trigger','event_trigger')  -- ← トリガー用関数を除外
         ORDER BY n.nspname, p.proname
    LOOP
        RAISE NOTICE '--------------------------------------';
        RAISE NOTICE 'Checking function: %.%', rec.schema_name, rec.function_name;
        RAISE NOTICE 'OID: %, Args: %', rec.oid, rec.argdef_str;

        -- 引数定義文字列をカンマで分割  (例: "IN a integer, OUT b text, IN c date")
        arg_array := string_to_array(rec.argdef_str, ',');

        -- 「SELECT schema_name.function_name(" の形でSQLを開始
        arg_sql := format('SELECT %I.%I(',
                          rec.schema_name,
                          rec.function_name);

        i := 0;
        IF arg_array IS NULL OR array_length(arg_array, 1) IS NULL THEN
            -- 引数がない場合
            arg_sql := arg_sql || ')';
        ELSE
            FOREACH parsed_arg IN ARRAY arg_array
            LOOP
                -- "IN" "OUT" "INOUT" "VARIADIC" を削除
                parsed_arg := trim(regexp_replace(trim(parsed_arg), '\b(IN|OUT|INOUT|VARIADIC)\b', '', 'gi'));

                -- "= デフォルト" 部分を削除
                parsed_arg := trim(regexp_replace(parsed_arg, '=[^,]+', '', 'g'));

                -- ここで "arg_name type" or "type" が残る
                IF parsed_arg ~ '\s' THEN
                    argtype := split_part(parsed_arg, ' ', 2);
                ELSE
                    argtype := parsed_arg;
                END IF;

                -- 型に応じて簡易デフォルト値を設定
                IF argtype ILIKE ANY(ARRAY['int','int2','int4','int8','integer','bigint','smallint','serial','bigserial','numeric','real','double precision']) THEN
                    parsed_arg := '0';
                ELSIF argtype ILIKE ANY(ARRAY['text','varchar','char','character','citext','bpchar','name']) THEN
                    parsed_arg := '''test''';
                ELSIF argtype ILIKE ANY(ARRAY['bool','boolean']) THEN
                    parsed_arg := 'FALSE';
                ELSIF argtype ILIKE 'date' THEN
                    parsed_arg := '''2025-01-01''';
                ELSIF argtype ILIKE ANY(ARRAY['timestamptz','timestamp','time','timetz','timestamp%']) THEN
                    parsed_arg := '''2025-01-01 00:00:00''';
                ELSIF argtype ILIKE ANY(ARRAY['json','jsonb']) THEN
                    parsed_arg := '''{}''';
                ELSE
                    -- ユーザー定義型や配列・複合などは NULL とする
                    parsed_arg := 'NULL';
                END IF;

                IF i > 0 THEN
                    arg_sql := arg_sql || ', ' || parsed_arg;
                ELSE
                    arg_sql := arg_sql || parsed_arg;
                END IF;
                i := i + 1;
            END LOOP;

            arg_sql := arg_sql || ')';
        END IF;

        -- セット返却関数(SRF)の可能性もあるので、LIMIT 1を付けて大量取得を避ける
        arg_sql := arg_sql || ' LIMIT 1;';

        RAISE NOTICE 'Exec SQL: %', arg_sql;

        BEGIN
            EXECUTE arg_sql;
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE 'Error calling function %.% : %',
                         rec.schema_name, rec.function_name, SQLERRM;
        END;
    END LOOP;

    RAISE NOTICE '==========================================';
    RAISE NOTICE '[INFO] 関数スモークテスト終了 (トリガー関数除外)';
    RAISE NOTICE '==========================================';

END
$$;
