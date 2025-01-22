-- エラーが起きたらそこで止まるよう設定
\set ON_ERROR_STOP on

\echo '=========================================='
\echo '[INFO] テーブル系オブジェクトチェック開始'
\echo '=========================================='

-- カタログを参照して、テーブル/ビュー/マテビュー/外部テーブルを抽出
-- relkind in ('r','p','v','m','f')
--   r: 通常のテーブル
--   p: パーティションテーブル
--   v: ビュー
--   m: マテビュー
--   f: 外部テーブル
-- システムスキーマ(pg_catalog, information_schema)と
-- pg_% で始まるオブジェクトを除外
SELECT format(
  $f$
    SELECT * 
      FROM %I.%I
     LIMIT 1;
  $f$,
  n.nspname,
  c.relname
)
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind IN ('r','p','v','m','f')
  AND n.nspname NOT IN ('pg_catalog','information_schema')
  AND c.relname NOT LIKE 'pg_%'
ORDER BY n.nspname, c.relname
\gexec

\echo '=========================================='
\echo '[INFO] テーブル系オブジェクトチェック終了'
\echo '=========================================='
