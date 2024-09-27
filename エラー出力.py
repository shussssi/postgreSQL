import os
import re
from datetime import datetime, timedelta

def parse_timestamp(timestamp_str):
    # タイムスタンプの形式に応じて適切にパースする
    return datetime.strptime(timestamp_str, '%m/%d %H:%M:%S')

def extract_errors(file_path, target_times):
    errors = []
    with open(file_path, 'r', encoding='utf-8', errors='ignore') as file:
        for line in file:
            timestamp_match = re.search(r'(\d{1,2}/\d{1,2} \d{2}:\d{2}:\d{2})', line)
            if timestamp_match:
                line_time = parse_timestamp(timestamp_match.group(1))
                for target_time in target_times:
                    if target_time - timedelta(hours=1) <= line_time <= target_time + timedelta(hours=1):
                        errors.append((line_time, line.strip()))
                        break
    return errors

def write_errors_to_file(errors, output_file):
    with open(output_file, 'w', encoding='utf-8') as file:
        for timestamp, error_line in errors:
            file.write(f"{timestamp}: {error_line}\n")

def main():
    target_times = [
        parse_timestamp('9/17 19:02:44'),
        parse_timestamp('9/18 02:51:11'),
        parse_timestamp('9/20 00:04:18'),
        parse_timestamp('9/20 00:04:56'),
        parse_timestamp('9/20 00:20:52'),
        parse_timestamp('9/20 11:28:24'),
        parse_timestamp('9/20 22:35:40'),
        parse_timestamp('9/20 23:21:04'),
        parse_timestamp('9/21 15:35:55'),
        parse_timestamp('9/23 14:02:52'),
        parse_timestamp('9/24 05:45:28'),
        parse_timestamp('9/24 23:39:21')
    ]

    log_folder = 'path/to/your/log/folder'  # ログファイルのあるフォルダパスを指定
    output_file = 'error_report.txt'  # 出力ファイル名
    all_errors = []

    for filename in os.listdir(log_folder):
        if filename.endswith('.log'):
            file_path = os.path.join(log_folder, filename)
            all_errors.extend(extract_errors(file_path, target_times))

    # エラーを時間順にソート
    all_errors.sort(key=lambda x: x[0])

    # 結果をファイルに出力
    write_errors_to_file(all_errors, output_file)

    print(f"エラーレポートが {output_file} に出力されました。")

    # オプション：コンソールにも出力
    for timestamp, error_line in all_errors:
        print(f"{timestamp}: {error_line}")

if __name__ == "__main__":
    main()
