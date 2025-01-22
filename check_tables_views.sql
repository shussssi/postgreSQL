\set ON_ERROR_STOP on

\echo '================================================='
\echo '[INFO] テーブル系オブジェクトチェック 開始'
\echo '================================================='

-- 
-- ここでカタログ(pg_class, pg_namespace)から
-- テーブル / ビュー / マテビュー / 外部テーブル / パーティションテーブル
-- を抽出し、「各オブジェクトで実行したいSQL文」を生成する
--
SELECT format(
  E'\\echo Checking: %I.%I\nSELECT * FROM %I.%I LIMIT 1;\n\\echo ""',
  n.nspname,      -- %I（スキーマ名 表示用）
  c.relname,      -- %I（テーブル等名 表示用）
  n.nspname,      -- %I（スキーマ名 SELECT用）
  c.relname       -- %I（テーブル等名 SELECT用）
)
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind IN ('r','p','v','m','f')
  -- r: 通常のテーブル
  -- p: パーティションテーブル
  -- v: ビュー
  -- m: マテリアライズドビュー
  -- f: 外部テーブル
  AND n.nspname NOT IN ('pg_catalog','information_schema')
  AND c.relname NOT LIKE 'pg_%'
ORDER BY n.nspname, c.relname
\gexec

\echo '================================================='
\echo '[INFO] テーブル系オブジェクトチェック 終了'
\echo '================================================='
