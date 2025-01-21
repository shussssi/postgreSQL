#!/bin/bash

###################################################
# 1. 接続設定
###################################################
HOST="localhost"
PORT="5432"
USER="postgres"

# ログ出力ディレクトリ（任意）
LOG_DIR="./logs"
mkdir -p "$LOG_DIR"

###################################################
# 2. データベース一覧取得
###################################################
# 以下のSQLでユーザーデータベースのみ取得
#   - template系や特定システムDB (postgres) を除外したい場合に条件を追加
DB_LIST=$(psql -h "$HOST" -p "$PORT" -U "$USER" -d postgres -Atc "
  SELECT datname
    FROM pg_database
   WHERE datistemplate = false
     AND datname NOT LIKE 'template%'
     AND datname NOT IN ('postgres')  -- 必要に応じて他DB名を除外
   ORDER BY datname;
")

if [[ -z "$DB_LIST" ]]; then
  echo "[ERROR] ユーザーデータベースが見つかりませんでした。"
  exit 1
fi

###################################################
# 3. 各DBでシーケンスをチェック
###################################################
for DBNAME in $DB_LIST; do

  LOGFILE="${LOG_DIR}/sequence_check_${DBNAME}_$(date +%Y%m%d_%H%M%S).log"

  # 標準出力と標準エラーをログに保存＆画面出力
  exec > >(tee -a "$LOGFILE") 2>&1

  echo "========================================================"
  echo "[INFO] シーケンス動作チェック開始"
  echo "Target Database: $DBNAME"
  echo "Host: $HOST  User: $USER"
  echo "日時: $(date)"
  echo "========================================================"
  echo

  # (1) シーケンス一覧をカタログから取得
  #   relkind='S' -> シーケンス
  #   システムスキーマ (pg_catalog, information_schema) や
  #   名前がpg_で始まるシステム系オブジェクトを除外
  SEQ_LIST=$(psql -h "$HOST" -p "$PORT" -U "$USER" -d "$DBNAME" -Atc "
    SELECT n.nspname || '.' || c.relname
      FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
     WHERE c.relkind = 'S'
       AND n.nspname NOT IN ('pg_catalog','information_schema')
       AND c.relname NOT LIKE 'pg_%'
     ORDER BY n.nspname, c.relname;
  ")

  if [[ -z "$SEQ_LIST" ]]; then
    echo "[INFO] シーケンスが見つかりませんでした: $DBNAME"
    continue
  fi

  # (2) 取得したシーケンスに対して nextval() を実行し、エラーがないかチェック
  while IFS= read -r seq_full_name; do
    echo "[INFO] Checking sequence: $seq_full_name"
    psql -h "$HOST" -p "$PORT" -U "$USER" -d "$DBNAME" -c "SELECT nextval('$seq_full_name');"
    echo
  done <<< "$SEQ_LIST"

  echo "========================================================"
  echo "[INFO] シーケンス動作チェック終了: $DBNAME"
  echo "ログ: $LOGFILE"
  echo "========================================================"
  echo

done
