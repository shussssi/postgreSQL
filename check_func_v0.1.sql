\set ON_ERROR_STOP on

-- +-------------------------------------------------+
-- | 1. 事前情報: 簡単な説明メッセージ              |
-- +-------------------------------------------------+
SELECT '==========================================' AS info
UNION ALL
SELECT '[INFO] 引数あり関数も含むスモークテスト開始' 
UNION ALL
SELECT 'このテストは引数に NULL や固定値を割り当てます。'
UNION ALL
SELECT '必ずしも本来の結果を正しく返すわけではありません。'
UNION ALL
SELECT '==========================================' 
;

--
-- 2. サーバー側で一括処理するため、PL/pgSQL の DO ブロックを使います
--    カタログ(pg_proc, pg_namespace)を参照して
--    - ユーザー定義スキーマ (pg_catalog, information_schema 以外)
--    - システムっぽい関数名(pg_で始まる)を除外
--    - p.prokind = 'f' (通常のFunction) あるいは 'p' (Procedure) を含めるなら条件を追加
--    などの関数をすべて列挙
--    → 引数をパースしてデフォルト値を決め → EXECUTE で呼び出しテスト
--
DO $$
DECLARE
    rec record;
    arg_array text[];
    parsed_arg text;
    argtype   text;
    arg_sql   text;   -- 最終的に呼び出す SQL
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
         WHERE n.nspname NOT IN ('pg_catalog','information_schema')
           AND p.proname NOT LIKE 'pg_%'
           AND p.prokind = 'f'  -- 'f': FUNCTIONのみ。プロシージャ含めたいなら OR で 'p' を加える
         ORDER BY n.nspname, p.proname
    LOOP
        RAISE NOTICE '--------------------------------------';
        RAISE NOTICE 'Checking function: %.%', rec.schema_name, rec.function_name;
        RAISE NOTICE 'OID: %, Args: %', rec.oid, rec.argdef_str;

        -- 引数定義文字列をカンマで分割
        -- 例: "IN a integer, OUT b text, IN c date"
        arg_array := string_to_array(rec.argdef_str, ',');

        -- 呼び出しSQLを組み立て開始
        -- 例えば "SELECT schema.func(" の形
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
                -- 先頭・末尾の空白除去
                parsed_arg := trim(parsed_arg);

                -- "IN", "OUT", "INOUT", "VARIADIC" を削除
                parsed_arg := regexp_replace(parsed_arg, '\b(IN|OUT|INOUT|VARIADIC)\b', '', 'gi');
                parsed_arg := trim(parsed_arg);

                -- "= デフォルト" 部分を削除
                parsed_arg := regexp_replace(parsed_arg, '=[^,]+', '', 'g');
                parsed_arg := trim(parsed_arg);

                -- ここで "arg_name type" or "type" だけが残るはず
                IF parsed_arg ~ '\s' THEN
                    -- スペースで区切られている場合、後半が型とみなす
                    argtype := split_part(parsed_arg, ' ', 2);
                ELSE
                    -- "type" だけ
                    argtype := parsed_arg;
                END IF;

                -- 簡易的な型判定 → デフォルト値を設定
                -- 必要に応じて増やしてください
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
                    -- ユーザー定義型や配列などは NULL
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

        -- SRF(セット返却)の可能性もあるので、一応 "LIMIT 1" をつける
        -- 戻り値がスカラーの場合でも問題なく動く
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
    RAISE NOTICE '[INFO] 関数スモークテスト終了';
    RAISE NOTICE '==========================================';

END
$$;
