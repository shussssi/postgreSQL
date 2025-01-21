#!/bin/bash

###################################################
# 1. 接続設定
###################################################
HOST="localhost"
PORT="5432"
USER="postgres"

# すべてのDBを対象にするため、DBNAMEは個別には指定しない

# ログディレクトリを指定 (任意)
LOG_DIR="./logs"
mkdir -p "$LOG_DIR"

###################################################
# 2. データベース一覧取得
###################################################
# 以下のSQLでユーザーデータベースのみ取得
#   - template0, template1, postgres, などシステム系を除外したい場合に条件を追加
#   - ここではシンプルに 'template%' を除外例としている
#   - 必要に応じて 'postgres' なども除外して下さい
DB_LIST=$(psql -h "$HOST" -p "$PORT" -U "$USER" -d postgres -Atc "
  SELECT datname
    FROM pg_database
   WHERE datistemplate = false
     AND datname NOT LIKE 'template%'
     AND datname NOT IN ('postgres')  -- 必要に応じて除外したいDB名を追加
   ORDER BY datname;
")

if [[ -z "$DB_LIST" ]]; then
  echo "[ERROR] ユーザーデータベースが見つかりませんでした。"
  exit 1
fi

###################################################
# 3. 各データベースでテーブル系オブジェクトをチェック
###################################################

for DBNAME in $DB_LIST; do

  # ログファイルをDBごとに分ける
  LOGFILE="${LOG_DIR}/table_view_check_${DBNAME}_$(date +%Y%m%d_%H%M%S).log"

  # 標準出力と標準エラーをログに保存＆画面出力
  exec > >(tee -a "$LOGFILE") 2>&1

  echo "========================================================"
  echo "[INFO] テーブル系オブジェクト SELECT チェック開始"
  echo "Target Database: $DBNAME"
  echo "Host: $HOST  User: $USER"
  echo "日時: $(date)"
  echo "========================================================"
  echo

  # カタログから、テーブル/ビュー/マテビュー/外部テーブルなどを抽出
  # relkind in ('r','p','v','m','f')
  #   r: テーブル
  #   p: パーティションテーブル
  #   v: ビュー
  #   m: マテリアライズドビュー
  #   f: 外部テーブル
  # システム系スキーマを除外 (pg_catalog, information_schema)
  psql -h "$HOST" -p "$PORT" -U "$USER" -d "$DBNAME" -Atc "
    SELECT n.nspname || '.' || c.relname
      FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
     WHERE c.relkind IN ('r','p','v','m','f')
       AND n.nspname NOT IN ('pg_catalog','information_schema')
       AND c.relname NOT LIKE 'pg_%'
     ORDER BY n.nspname, c.relname;
  " | while read -r full_name; do
      echo "[INFO] Checking: $full_name"
      # LIMIT 1 で最低限のSELECTテスト
      psql -h "$HOST" -p "$PORT" -U "$USER" -d "$DBNAME" -c "SELECT * FROM $full_name LIMIT 1;"
      echo
  done

  echo "========================================================"
  echo "[INFO] テーブル系オブジェクト SELECT チェック終了: $DBNAME"
  echo "ログ: $LOGFILE"
  echo "========================================================"
  echo

done
