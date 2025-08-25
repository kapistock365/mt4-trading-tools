# ファイル構造と依存関係マップ

## 📁 完全なファイルツリー

```
mt4-trading-tools/
│
├── 📁 Experts/
│   └── 📄 FX5MinScalpingEA.mq4 (メインEA - 2,832行)
│
├── 📁 Include/
│   ├── 📁 Core/ (既存ライブラリ)
│   │   ├── 📄 OrderManager.mqh
│   │   └── 📄 AccountManager.mqh
│   │
│   ├── 📄 PluginBase.mqh (既存)
│   │
│   └── 📁 FX5MinScalping/ (新規開発)
│       ├── 📄 DataStructures.mqh (313行)
│       ├── 📄 MarketAnalyzer.mqh (645行)
│       ├── 📄 BuildupDetector.mqh (472行)
│       ├── 📄 PatternBreakPlugin.mqh (685行)
│       ├── 📄 PBPullbackPlugin.mqh (701行)
│       ├── 📄 PBComboPlugin.mqh (569行)
│       ├── 📄 TimeFilter.mqh (478行)
│       ├── 📄 SpreadFilter.mqh (647行)
│       └── 📄 ConfigManager.mqh (618行)
│
├── 📁 Files/
│   └── 📁 FX5MinScalping/
│       ├── 📄 README.md
│       └── 📁 Profiles/
│           ├── 📄 Safe.conf
│           ├── 📄 Balanced.conf
│           └── 📄 Aggressive.conf
│
└── 📁 docs/
    └── 📁 fx-scalping/
        ├── 📄 README.md
        ├── 📄 BOOK_SUMMARY.md
        ├── 📄 SETUP_DOCUMENTATION.md
        ├── 📄 EA_ARCHITECTURE_DESIGN.md
        ├── 📄 PLUGIN_DETAILED_DESIGN.md
        ├── 📄 DATA_INTERFACE_SPECIFICATION.md
        ├── 📄 BACKTEST_PLAN.md
        ├── 📄 TESTING_GUIDE.md
        ├── 📄 USER_MANUAL.md
        ├── 📄 QUICK_START_GUIDE.md
        ├── 📄 PROJECT_COMPLETION_REPORT.md
        ├── 📄 HANDOVER_GUIDE.md
        └── 📄 FILE_STRUCTURE.md (このファイル)
```

## 🔗 インクルード依存関係

### FX5MinScalpingEA.mq4のインクルード
```cpp
// 既存ライブラリ
#include <Core/OrderManager.mqh>
#include <Core/AccountManager.mqh>

// FX5MinScalpingモジュール
#include <FX5MinScalping/DataStructures.mqh>
#include <FX5MinScalping/MarketAnalyzer.mqh>
#include <FX5MinScalping/BuildupDetector.mqh>
#include <FX5MinScalping/PatternBreakPlugin.mqh>
#include <FX5MinScalping/PBPullbackPlugin.mqh>
#include <FX5MinScalping/PBComboPlugin.mqh>
#include <FX5MinScalping/TimeFilter.mqh>
#include <FX5MinScalping/SpreadFilter.mqh>
#include <FX5MinScalping/ConfigManager.mqh>
```

### 各プラグインの依存関係
```cpp
// PatternBreakPlugin.mqh
#include "DataStructures.mqh"
#include "MarketAnalyzer.mqh"
#include "BuildupDetector.mqh"

// PBPullbackPlugin.mqh
#include "DataStructures.mqh"
#include "MarketAnalyzer.mqh"
#include "BuildupDetector.mqh"

// PBComboPlugin.mqh
#include "DataStructures.mqh"
#include "MarketAnalyzer.mqh"
#include "BuildupDetector.mqh"

// TimeFilter.mqh
// 依存なし（独立モジュール）

// SpreadFilter.mqh
#include "DataStructures.mqh"

// ConfigManager.mqh
// 依存なし（独立モジュール）

// MarketAnalyzer.mqh
#include "DataStructures.mqh"

// BuildupDetector.mqh
#include "DataStructures.mqh"
```

## 📊 コード統計

### ソースコード行数
| ファイル | 行数 | 主要クラス/関数数 |
|---------|------|------------------|
| FX5MinScalpingEA.mq4 | 2,832 | 15関数 |
| DataStructures.mqh | 313 | 12構造体, 5関数 |
| MarketAnalyzer.mqh | 645 | 1クラス, 20メソッド |
| BuildupDetector.mqh | 472 | 1クラス, 15メソッド |
| PatternBreakPlugin.mqh | 685 | 1クラス, 18メソッド |
| PBPullbackPlugin.mqh | 701 | 1クラス, 22メソッド |
| PBComboPlugin.mqh | 569 | 1クラス, 19メソッド |
| TimeFilter.mqh | 478 | 1クラス, 16メソッド |
| SpreadFilter.mqh | 647 | 1クラス, 20メソッド |
| ConfigManager.mqh | 618 | 1クラス, 12メソッド |
| **合計** | **7,960行** | **9クラス, 157メソッド** |

### ドキュメント統計
| カテゴリ | ファイル数 | 総行数 |
|---------|-----------|--------|
| 設計書 | 6 | 約3,000行 |
| ユーザーガイド | 3 | 約2,500行 |
| 技術文書 | 4 | 約1,500行 |
| **合計** | **13** | **約7,000行** |

## 🏗️ アーキテクチャ図

```
┌─────────────────────────────────────┐
│     FX5MinScalpingEA (Main)         │
├─────────────────────────────────────┤
│  - OnInit()                         │
│  - OnTick()                         │
│  - OnDeinit()                       │
└────────────┬───────────────────────┘
             │
    ┌────────┴────────┬────────┬────────┐
    ▼                 ▼        ▼        ▼
┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐
│ Filters  │  │ Plugins  │  │ Analyzers│  │ Managers │
├──────────┤  ├──────────┤  ├──────────┤  ├──────────┤
│TimeFilter│  │PB Plugin │  │Market    │  │Order     │
│Spread    │  │Pullback  │  │Analyzer  │  │Manager   │
│Filter    │  │Combo     │  │Buildup   │  │Account   │
│          │  │          │  │Detector  │  │Manager   │
└──────────┘  └──────────┘  └──────────┘  └──────────┘
      │              │             │             │
      └──────────────┴─────────────┴─────────────┘
                           │
                    ┌──────┴──────┐
                    │DataStructures│
                    └──────────────┘
```

## 🔍 重要な関数/メソッド一覧

### FX5MinScalpingEA.mq4
```cpp
int OnInit()                     // EA初期化
void OnTick()                    // ティック処理
void OnDeinit(const int reason)  // EA終了処理
void CheckForSignals()           // シグナルチェック
void ExecuteTrade(SignalInfo &signal) // トレード実行
void UpdateDisplay()             // 画面更新
void ManagePositions()           // ポジション管理
bool CheckFilters()              // フィルターチェック
```

### PatternBreakPlugin.mqh
```cpp
bool Initialize()                // 初期化
void OnTick()                   // ティック処理
bool GetSignal(SignalInfo &signal) // シグナル取得
void DrawVisualization()        // 可視化
bool DetectBreakout()           // ブレイクアウト検出
```

### MarketAnalyzer.mqh
```cpp
bool Initialize()               // 初期化
void UpdateAnalysis()           // 分析更新
MarketCondition GetMarketCondition() // 市場状態取得
bool IsOptimalTradingTime()    // 最適時間判定
double GetTrendStrength()       // トレンド強度
```

### ConfigManager.mqh
```cpp
bool SaveProfile(string name)   // プロファイル保存
bool LoadProfile(string name)   // プロファイル読込
void GetProfileList(string &list[]) // リスト取得
bool ExportProfileAsJSON()      // JSON出力
```

## 🔧 MT4へのインストール手順

### 1. フォルダ構造の確認
```
MT4インストールフォルダ/
├── MQL4/
│   ├── Experts/
│   ├── Include/
│   ├── Files/
│   └── Scripts/
```

### 2. ファイルコピー
```bash
# Expertsフォルダへ
cp Experts/FX5MinScalpingEA.mq4 → MQL4/Experts/

# Includeフォルダへ（フォルダごと）
cp -r Include/FX5MinScalping → MQL4/Include/

# Filesフォルダへ（フォルダごと）
cp -r Files/FX5MinScalping → MQL4/Files/

# 既存Core確認（既にある場合はスキップ）
MQL4/Include/Core/OrderManager.mqh
MQL4/Include/Core/AccountManager.mqh
```

### 3. コンパイル順序
1. DataStructures.mqh（依存なし）
2. MarketAnalyzer.mqh（DataStructures依存）
3. BuildupDetector.mqh（DataStructures依存）
4. 各プラグイン（上記3つに依存）
5. FX5MinScalpingEA.mq4（全てに依存）

## ⚠️ 注意事項

### パスの問題
- 相対パス使用: `#include "FX5MinScalping/..."`
- 絶対パス使用: `#include <FX5MinScalping/...>`
- MT4のバージョンによって挙動が異なる

### 文字コード
- UTF-8で保存されている
- MetaEditorはANSIがデフォルト
- 日本語コメントが文字化けする可能性

### 既存ライブラリとの競合
- Core/OrderManager.mqhが既に存在する場合
- クラス名の重複に注意
- 名前空間がないため直接的な競合

## 📝 クイックデバッグ

### ファイル存在確認
```cpp
// OnInit()に追加
if(!FileIsExist("FX5MinScalping\\Profiles\\Safe.conf")) {
    Print("Warning: Config files not found");
}
```

### インクルード確認
```cpp
// 各ファイルの先頭に追加
#ifdef _DEBUG
    #pragma message("File included: " __FILE__)
#endif
```

### 初期化確認
```cpp
// OnInit()の各段階で
Print("Step 1: Data structures OK");
Print("Step 2: Market analyzer OK");
Print("Step 3: Plugins OK");
```

---

*このドキュメントはMT4への移植時の参考資料です*
*最終更新: 2025-08-25*