# MT4 Trading Tools

MetaTrader 4用のEA（Expert Advisors）とカスタムインジケーターのリポジトリです。

## クイックスタート（開発者向け）

```bash
# リポジトリをクローン
git clone https://github.com/kapistock365/mt4-trading-tools.git
cd mt4-trading-tools

# Claude Codeで開発開始（.clinerrulesが自動的に読み込まれます）
claude
```

### MQL4ファイルの文字化け対策
MQL4ファイルがUTF-16LEで保存されている場合、以下のコマンドで読めます：
```bash
iconv -f UTF-16LE -t UTF-8 ファイル名
```

## ディレクトリ構造

- `Experts/` - EA（自動売買プログラム）
- `Indicators/` - カスタムインジケーター
- `Scripts/` - スクリプト（単発実行プログラム）
- `Include/` - 共通ライブラリ・ヘッダーファイル
- `Files/` - データファイル、設定ファイルなど

## 開発環境

- MetaTrader 4
- MetaEditor

## インストール方法

1. MetaTrader 4のデータフォルダを開く（ファイル → データフォルダを開く）
2. MQL4フォルダ内の対応するフォルダに各ファイルをコピー
3. MetaTrader 4を再起動またはナビゲーターを更新

## 利用可能なツール

### インジケーター

1. **TrendBreakout.mq4**
   - サポート・レジスタンスの自動検出
   - ブレイクアウトアラート機能
   - トレンド強度表示（ADX）

2. **RiskMonitor.mq4**
   - リアルタイムリスク監視
   - 日次損益・勝率表示
   - リスクリワード比計算
   - 損失制限警告機能

### EA（Expert Advisors）

1. **UnifiedTradingEA.mq4** 🆕 **推奨**
   - プラグインシステム採用
   - 複数機能を1つのEAに統合
   - 動的な機能ON/OFF
   - 統合GUI管理
   
   **含まれるプラグイン:**
   - ブレイクアウトプラグイン
   - リスク管理プラグイン
   - (今後も追加予定)

2. **TrendFollowEA.mq4** (単体版)
   - ブレイクアウト自動エントリー
   - トレンドフィルター機能
   - 自動ロット計算

3. **RiskManagerEA.mq4** (単体版)
   - 自動損切り設定
   - トレーリングストップ
   - 部分決済機能
   - 日次損失制限
   - ブレークイーブン機能

4. **CT_Trail_2.00**
   - 両建て対応
   - GUI操作パネル
   - 高度なトレーリング機能

## 使用方法

1. MetaTrader 4のデータフォルダを開く
2. MQL4フォルダ内の対応するフォルダにファイルをコピー
3. MetaTrader 4でコンパイル（F7）
4. チャートに適用

## リスク管理の推奨設定

- 1トレードあたりの最大リスク: 1-2%
- 日次最大損失: 5%
- リスクリワード比: 1:2以上

## ライセンス

MIT License