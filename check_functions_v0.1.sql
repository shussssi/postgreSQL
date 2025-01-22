\set ON_ERROR_STOP on

\echo '================================================='
\echo '[INFO] 関数チェック（引数なし）開始'
\echo '================================================='

-- 
-- カタログ (pg_proc, pg_namespace) を参照して
--   ・ユーザー定義スキーマ内の
--   ・引数なし (pg_get_function_arguments(...) = '')
--   ・通常のFUNCTION (prokind = 'f')
-- のみを対象に、呼び出しSQLを動的生成
--
SELECT format(
  $$
    SELECT 'Checking function: %I.%I' AS function_name;
    SELECT %I.%I() AS result;
  $$,
  n.nspname,     -- 関数スキーマ名（表示用）
  p.proname,     -- 関数名（表示用）
  n.nspname,     -- 関数スキーマ名（呼び出し用）
  p.proname      -- 関数名（呼び出し用）
)
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.prokind = 'f'                -- 通常のFunction
  AND pg_catalog.pg_get_function_arguments(p.oid) = '' 
  -- ↑ 引数なし関数だけ対象
  AND n.nspname NOT IN ('pg_catalog','information_schema')
  AND p.proname NOT LIKE 'pg_%'       -- システム系っぽい関数を除外
ORDER BY n.nspname, p.proname
\gexec

\echo '================================================='
\echo '[INFO] 関数チェック（引数なし）終了'
\echo '================================================='
