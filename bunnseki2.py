import pandas as pd
import numpy as np
from difflib import SequenceMatcher

def calculate_similarity(str1, str2):
    """difflibのSequenceMatcherを使用して文字列の類似性を計算します"""
    return SequenceMatcher(None, str1, str2).ratio()

def find_similar_objects(df, similarity_threshold=0.8):
    """類似したオブジェクトを見つけます"""
    similar_objects = []
    n = len(df)
    
    for i in range(n):
        for j in range(i+1, n):
            name_similarity = calculate_similarity(df.iloc[i]['オブジェクト名'], df.iloc[j]['オブジェクト名'])
            definition_similarity = calculate_similarity(df.iloc[i]['オブジェクト定義'], df.iloc[j]['オブジェクト定義'])
            
            avg_similarity = (name_similarity + definition_similarity) / 2
            
            if avg_similarity >= similarity_threshold:
                similar_objects.append({
                    'Object1': df.iloc[i]['オブジェクト名'],
                    'Object2': df.iloc[j]['オブジェクト名'],
                    'Similarity': avg_similarity,
                    'Type': df.iloc[i]['オブジェクトタイプ'],
                    'Schema': df.iloc[i]['スキーマ名']
                })
    
    return pd.DataFrame(similar_objects)

# Excelファイルを読み込む
file_path = 'path_to_your_excel_file.xlsx'  # ファイルパスを適切に設定してください
df = pd.read_excel(file_path)

# 列名を確認し、必要に応じて変更する
df.columns = ['オブジェクトタイプ', 'スキーマ名', 'オブジェクト名', 'オブジェクトオーナー名', 'オブジェクト定義']

# 類似オブジェクトを見つける
similar_objects = find_similar_objects(df)

# 結果を表示
print(similar_objects.sort_values('Similarity', ascending=False))

# オプション: 結果をCSVファイルに保存
similar_objects.to_csv('similar_objects.csv', index=False)
