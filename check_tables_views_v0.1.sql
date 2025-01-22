\set ON_ERROR_STOP on

-- すべてのテーブル/ビュー/マテビュー/外部テーブルを列挙し、
-- 「オブジェクト名の表示 → 1行だけ SELECT して確認」するSQL文を動的に生成
-- ※ \gexec は psql のメタコマンド。psql 経由なら有効
SELECT format(
  $$
    SELECT 'Checking: %I.%I' AS object_name;
    SELECT * FROM %I.%I LIMIT 1;
  $$,
  n.nspname,  -- %I (スキーマ名)
  c.relname,  -- %I (テーブル or ビュー名)
  n.nspname,
  c.relname
)
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind IN ('r','p','v','m','f')
  -- r: 通常テーブル, p: パーティションテーブル, v: ビュー
  -- m: マテビュー, f: 外部テーブル
  AND n.nspname NOT IN ('pg_catalog','information_schema')
  AND c.relname NOT LIKE 'pg_%'
ORDER BY n.nspname, c.relname
\gexec

-- 全部実行したあとに確認メッセージを出したい場合は、下記のように追加
-- （\echo はメタコマンドなので、もし使えない環境なら代わりに
--  SELECT 'All checks done' AS message; のように SQL で出力してもOK）
\echo 'All table/view checks are done.'
