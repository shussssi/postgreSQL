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
# 2. ユーザーデータベース一覧の取得
###################################################
DB_LIST=$(psql -h "$HOST" -p "$PORT" -U "$USER" -d postgres -Atc "
  SELECT datname
    FROM pg_database
   WHERE datistemplate = false
     AND datname NOT LIKE 'template%'
     AND datname NOT IN ('postgres')  -- システムDBを除外したい場合はここに追記
   ORDER BY datname;
")

if [[ -z "$DB_LIST" ]]; then
  echo "[ERROR] ユーザーデータベースが見つかりませんでした。"
  exit 1
fi

###################################################
# 3. 各DBでSRFを列挙 & 引数を解析してスモークテスト
###################################################
for DBNAME in $DB_LIST; do

  LOGFILE="${LOG_DIR}/srf_arg_check_${DBNAME}_$(date +%Y%m%d_%H%M%S).log"

  # 標準出力と標準エラーをログに保存＆画面出力
  exec > >(tee -a "$LOGFILE") 2>&1

  echo "========================================================"
  echo "[INFO] セット返却関数 (SRF) 引数ありスモークテスト開始"
  echo "Target Database: $DBNAME"
  echo "Host: $HOST  User: $USER"
  echo "日時: $(date)"
  echo "========================================================"
  echo

  #  (1) SRF(セット返却) 関数を列挙:
  #    prokind='f' -> 通常のFUNCTION
  #    proretset=true -> set-returning
  #  システムスキーマ/関数名を除外
  SRF_LIST=$(psql -h "$HOST" -p "$PORT" -U "$USER" -d "$DBNAME" -Atc "
    SELECT p.oid
      FROM pg_proc p
      JOIN pg_namespace n ON p.pronamespace = n.oid
     WHERE p.prokind = 'f'
       AND p.proretset = true
       AND n.nspname NOT IN ('pg_catalog','information_schema')
       AND p.proname NOT LIKE 'pg_%'
     ORDER BY n.nspname, p.proname;
  ")

  if [[ -z "$SRF_LIST" ]]; then
    echo "[INFO] SRFが見つかりませんでした: $DBNAME"
    continue
  fi

  # SRFごとにループ
  while IFS= read -r proc_oid; do
    # (2) スキーマ名.関数名 と 引数定義を取得
    read -r schema_name func_name argdef_str < <( \
      psql -h "$HOST" -p "$PORT" -U "$USER" -d "$DBNAME" -Atc "
        SELECT n.nspname,
               p.proname,
               pg_catalog.pg_get_function_arguments(p.oid)
          FROM pg_proc p
          JOIN pg_namespace n ON p.pronamespace = n.oid
         WHERE p.oid = $proc_oid
      "
    )

    echo "[INFO] Checking SRF: ${schema_name}.${func_name}"

    # (3) 引数リストのパース
    #     argdef_str 例: "IN arg1 integer, OUT arg2 text, IN arg3 date=DEFAULT_VAL"
    #     ここから「引数名/型/INOUT」などを取り除いて、デフォルト値を割り当てる
    IFS=',' read -ra args_array <<< "$argdef_str"

    call_args=()

    for raw_arg in "${args_array[@]}"; do
      # 前後空白除去
      argdef="$(echo "$raw_arg" | sed 's/^ *//;s/ *$//')"
      # "IN" "OUT" "INOUT" "VARIADIC" 等を除去
      argdef="$(echo "$argdef" | sed -E 's/\b(IN|OUT|INOUT|VARIADIC)\b//g' | sed 's/^ *//;s/ *$//')"
      # "= デフォルト" も除去 (厳密には引数に持つかもしれないが今回は自動割当を優先)
      argdef="$(echo "$argdef" | sed -E 's/=[^,]+//')"
      # スペース区切りで「argname, argtype」に分割
      # ただし argname が省略されているケースもあるのでケアが必要
      arg_name="$(echo "$argdef" | awk '{print $1}')"
      arg_type="$(echo "$argdef" | awk '{print $2}')"

      # arg_type が空の場合、(例: "arg1 integer" でなく "integer" だけなど) 
      # そこは再パース
      if [[ -z "$arg_type" ]]; then
        arg_type="$arg_name"  # 1単語しかないならそれは型
        arg_name=""
      fi

      # 型に応じたデフォルト値を決定
      default_val="NULL"

      case "$arg_type" in
        # 数値系
        int|int2|int4|int8|integer|bigint|smallint|serial|bigserial|numeric|real|double*)
          default_val="0"
          ;;
        # 文字列系
        text|char|varchar|character|name|citext|bpchar)
          default_val="'test'"
          ;;
        bool|boolean)
          default_val="FALSE"
          ;;
        date)
          default_val="'2025-01-01'"
          ;;
        timestamptz|timestamp|time|timetz|abstime|timestamptz*)
          default_val="'2025-01-01 00:00:00'"
          ;;
        json|jsonb)
          default_val="'{}'"
          ;;
        # その他(配列型、ユーザー定義型など)
        #  ひとまず NULL にして呼び出す
        *)
          default_val="NULL"
          ;;
      esac

      call_args+=("$default_val")

    done

    # 引数一覧をカンマ区切りで連結
    joined_args="$(IFS=,; echo "${call_args[*]}")"

    # (4) 呼び出し文を生成: SRF は "SELECT * FROM s.f(a1, a2, ...) LIMIT 1"
    # 引数がゼロ個の場合は () のまま
    if [ -z "$joined_args" ]; then
      sql_call="SELECT * FROM ${schema_name}.${func_name}() LIMIT 1;"
    else
      sql_call="SELECT * FROM ${schema_name}.${func_name}(${joined_args}) LIMIT 1;"
    fi

    echo "[SQL] $sql_call"
    psql -h "$HOST" -p "$PORT" -U "$USER" -d "$DBNAME" -c "$sql_call"
    echo
  done <<< "$SRF_LIST"

  echo "========================================================"
  echo "[INFO] セット返却関数 (SRF) スモークテスト終了: $DBNAME"
  echo "ログ: $LOGFILE"
  echo "========================================================"
  echo

done
