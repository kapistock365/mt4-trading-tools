# MT4 Trading Tools プロジェクト構造

## ディレクトリ構造

```
mt4-trading-tools/
│
├── 📁 Experts/                         # EA（Expert Advisors）
│   ├── 🎯 UnifiedTradingEA.mq4        # 【メイン】統合EA
│   ├── TrendFollowEA.mq4              # ブレイクアウトEA（単体版）
│   └── RiskManagerEA.mq4              # リスク管理EA（単体版）
│
├── 📁 Indicators/                      # カスタムインジケーター
│   ├── TrendBreakout.mq4              # ブレイクアウト検出
│   └── RiskMonitor.mq4                # リスク監視
│
├── 📁 Include/                         # ヘッダーファイル
│   ├── ⚙️ PluginBase.mqh              # プラグイン基底クラス
│   └── 📁 Plugins/                    # プラグイン実装
│       ├── BreakoutPlugin.mqh         # ブレイクアウトプラグイン
│       └── RiskManagerPlugin.mqh      # リスク管理プラグイン
│
├── 📁 CT_Trail_2.00/                   # 既存ライブラリ（レガシー）
│   ├── CT_Trail_2.00.mq4              # トレーリングストップEA
│   └── 📁 Include/
│       ├── AccountManager.mqh         # 口座管理
│       ├── OrderManager.mqh           # 注文管理
│       ├── GuiManager.mqh             # GUI管理
│       └── Constants.mqh              # 定数定義
│
├── 📁 Scripts/                         # スクリプト（空）
├── 📁 Files/                           # データファイル（空）
│
├── 📄 README.md                        # プロジェクト概要
├── 📄 CLAUDE.md                        # 開発履歴・コンテキスト
├── 📄 ARCHITECTURE.md                  # システム設計書
├── 📄 DEVELOPMENT.md                   # 開発ガイドライン
├── 📄 PROJECT_STRUCTURE.md             # このファイル
├── 📄 .clinerules                      # Claude Code自動設定
└── 📄 .gitignore                       # Git除外設定
```

## コンポーネント関係図

```
┌─────────────────────────────────────────────────────┐
│                  ユーザー                            │
└─────────────────────┬───────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────┐
│              UnifiedTradingEA                       │
│  ┌─────────────┬─────────────┬─────────────┐      │
│  │ Plugin      │  Order      │  Account    │      │
│  │ Manager     │  Manager    │  Manager    │      │
│  └──────┬──────┴──────┬──────┴──────┬──────┘      │
│         │             │             │              │
│         ▼             ▼             ▼              │
│  ┌─────────────┬─────────────┬─────────────┐      │
│  │ Breakout    │ RiskManager │   Future    │      │
│  │ Plugin      │   Plugin    │  Plugins    │      │
│  └─────────────┴─────────────┴─────────────┘      │
└─────────────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────┐
│                 MetaTrader 4                        │
│                  (取引実行)                          │
└─────────────────────────────────────────────────────┘
```

## ファイルタイプ別統計

| タイプ | ファイル数 | 用途 |
|--------|-----------|------|
| EA (.mq4) | 4 | 自動売買プログラム |
| インジケーター (.mq4) | 2 | チャート分析 |
| ライブラリ (.mqh) | 8 | 共通機能 |
| ドキュメント (.md) | 5 | 開発文書 |
| 設定ファイル | 2 | プロジェクト設定 |

## 主要コンポーネント

### 1. UnifiedTradingEA（統合EA）
- **役割**: すべての機能を統合するメインEA
- **特徴**: プラグインシステム採用
- **推奨**: 新規利用者はこれを使用

### 2. プラグインシステム
- **PluginBase.mqh**: 基底クラス
- **BreakoutPlugin**: ブレイクアウト検出
- **RiskManagerPlugin**: リスク管理
- **拡張可能**: 新規プラグイン追加が容易

### 3. レガシーコンポーネント
- **TrendFollowEA**: 単体版（互換性維持）
- **RiskManagerEA**: 単体版（互換性維持）
- **CT_Trail_2.00**: 既存ライブラリ

## 開発フロー

```
1. 新機能の企画
    ↓
2. プラグインとして設計
    ↓
3. Include/Plugins/に実装
    ↓
4. UnifiedTradingEAに統合
    ↓
5. テスト・デバッグ
    ↓
6. ドキュメント更新
```

## クイックスタート

### 使用者向け
1. `UnifiedTradingEA.mq4`をMT4にインストール
2. チャートに適用
3. 設定パネルから機能を選択

### 開発者向け
1. リポジトリをクローン
2. `DEVELOPMENT.md`を読む
3. `Include/Plugins/`に新規プラグイン作成
4. テストして統合

---

最終更新: 2025年1月