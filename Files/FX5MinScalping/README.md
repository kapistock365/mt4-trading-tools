# FX5MinScalping 設定ファイル

## 📁 フォルダ構成

```
Files/FX5MinScalping/
├── README.md              # このファイル
├── Profiles/              # プロファイル保存フォルダ
│   ├── Safe.conf         # 安全設定（初心者向け）
│   ├── Balanced.conf     # バランス設定（標準）
│   └── Aggressive.conf   # アグレッシブ設定（上級者向け）
└── Logs/                 # ログファイル（自動生成）
```

## 🎯 プロファイルの使い方

### MT4での設定

1. **プロファイル選択**
   - EA設定画面で `LoadProfile` パラメータに名前を入力
   - 例: "Safe", "Balanced", "Aggressive"

2. **カスタムプロファイル作成**
   - EA稼働中に現在の設定を保存可能
   - 設定画面で `SaveProfileName` に名前を入力して保存

3. **プロファイル切り替え**
   - 異なる相場環境に応じてプロファイルを切り替え
   - レンジ相場: Safe
   - 通常相場: Balanced
   - トレンド相場: Aggressive

## 📊 プリセットプロファイル比較

| 設定項目 | Safe | Balanced | Aggressive |
|---------|------|----------|------------|
| リスク% | 1.0% | 1.5% | 2.0% |
| 自動ロット | OFF | ON | ON |
| Pattern Break | ON | ON | ON |
| PB Pullback | OFF | ON | ON |
| PB Combo | OFF | OFF | ON |
| 損切り(pips) | 12 | 10 | 10 |
| 利確(pips) | 20 | 20 | 20 |
| 最大取引/日 | 3 | 5 | 10 |
| 最大損失/日 | 3% | 5% | 5% |
| トレール | OFF | ON | ON |

## 🔧 設定ファイルの編集

### 直接編集する場合

設定ファイルはテキスト形式なので、メモ帳等で直接編集可能です。

```ini
[Basic Settings]
RiskPercent=1.50        # 1トレードのリスク割合
DefaultLots=0.01        # 固定ロット数
UseAutoLot=true         # 自動ロット計算（true/false）

[Strategy Settings]
EnablePatternBreak=true # パターンブレイク戦略
EnablePBPullback=true   # プルバック戦略
EnablePBCombo=false     # コンボ戦略
```

### 注意事項

- 数値は小数点表記（例: 1.50）
- ブール値は true/false
- コメントは # で開始
- セクション名は [] で囲む

## 📝 カスタムプロファイルの例

### スキャルピング特化
```ini
# 高頻度トレード用
[Basic Settings]
RiskPercent=0.50
DefaultLots=0.01
UseAutoLot=false

[Pattern Break Settings]
MinBuildupBars=2
BreakoutMinPips=1.0

[Risk Management]
MaxTradesPerDay=20
StopLossPips=5.0
TakeProfitPips=10.0
```

### ニュース回避
```ini
# 重要指標回避用
[Filter Settings]
UseTimeFilter=true
StartHour=9
EndHour=20
MaxSpreadPips=1.5

[Risk Management]
MaxTradesPerDay=2
CooldownMinutes=60
```

### 週末専用
```ini
# 金曜日用設定
[Basic Settings]
RiskPercent=0.50

[Filter Settings]
EndHour=20

[Risk Management]
MaxTradesPerDay=2
MaxDailyLoss=2.0
```

## 🔄 バックアップ

定期的にProfilesフォルダ全体をバックアップすることを推奨します。

```
バックアップ先の例:
- クラウドストレージ（Google Drive等）
- 外部ストレージ
- 別のPCへコピー
```

## ⚠️ トラブルシューティング

### プロファイルが読み込めない
- ファイル名の確認（.conf拡張子必須）
- ファイルパスの確認
- 文字コードがUTF-8か確認

### 設定が反映されない
- EAの再起動が必要な場合があります
- チャートからEAを削除して再適用

### ファイルが見つからない
- MT4のデータフォルダを確認
- Files/FX5MinScalping/Profiles/ に配置

---
*最終更新: 2025-08-25*