# FX 5分足スキャルピングEA 引き継ぎガイド

## 🎯 このドキュメントの目的
別のPCやClaude Codeセッションで開発を継続するための完全な引き継ぎガイドです。

---

## 📥 引き継ぎ手順（新しいPC/セッション）

### 1. リポジトリのクローン
```bash
# GitHubからクローン
git clone https://github.com/kapistock365/mt4-trading-tools.git
cd mt4-trading-tools

# 開発ブランチに切り替え
git checkout fx-scalping-integration

# 最新の状態を確認
git pull origin fx-scalping-integration
```

### 2. Claude Codeへの説明文
新しいClaude Codeセッションで以下を伝えてください：

```
FX 5分足スキャルピングEAの開発を引き継ぎます。
GitHubリポジトリ: https://github.com/kapistock365/mt4-trading-tools
ブランチ: fx-scalping-integration

以下のドキュメントを確認してください：
1. /docs/fx-scalping/HANDOVER_GUIDE.md - 引き継ぎガイド
2. /docs/fx-scalping/PROJECT_COMPLETION_REPORT.md - 完了報告
3. /CLAUDE.md - プロジェクト全体のコンテキスト

MT4でコンパイルしたところ、[具体的なエラー内容]が発生しました。
修正をお願いします。
```

---

## 📁 重要ファイル一覧と役割

### コアファイル（修正対象になりやすい）

| ファイル | 場所 | 役割 | よくある修正 |
|---------|------|------|-------------|
| FX5MinScalpingEA.mq4 | Experts/ | メインEA | パラメータ調整、初期化エラー |
| DataStructures.mqh | Include/FX5MinScalping/ | データ型定義 | 構造体の追加/修正 |
| PatternBreakPlugin.mqh | Include/FX5MinScalping/ | 基本戦略 | エントリー条件調整 |
| ConfigManager.mqh | Include/FX5MinScalping/ | 設定管理 | ファイルパス問題 |

### 依存関係マップ
```
FX5MinScalpingEA.mq4
├── DataStructures.mqh（必須）
├── MarketAnalyzer.mqh
│   └── DataStructures.mqh
├── BuildupDetector.mqh
│   └── DataStructures.mqh
├── PatternBreakPlugin.mqh
│   ├── DataStructures.mqh
│   ├── MarketAnalyzer.mqh
│   └── BuildupDetector.mqh
├── PBPullbackPlugin.mqh（同上）
├── PBComboPlugin.mqh（同上）
├── TimeFilter.mqh
├── SpreadFilter.mqh
└── ConfigManager.mqh
```

---

## 🔧 MT4コンパイル時の一般的なエラーと対処法

### 1. インクルードファイルが見つからない
```
エラー: cannot open include file 'FX5MinScalping/DataStructures.mqh'
```
**対処法**:
```cpp
// 相対パスから絶対パスに変更
#include <FX5MinScalping/DataStructures.mqh>  // 修正前
#include "FX5MinScalping/DataStructures.mqh"   // 修正後
```

### 2. 既存ライブラリとの競合
```
エラー: 'COrderManager' - identifier already defined
```
**対処法**:
- Core/OrderManager.mqhとの名前空間競合
- クラス名をCFX5OrderManagerなどに変更

### 3. MQL4バージョン差異
```
エラー: 'SymbolInfoDouble' - function not defined
```
**対処法**:
```cpp
// 新しい関数を古い関数に置換
double spread = SymbolInfoDouble(Symbol(), SYMBOL_SPREAD);  // 修正前
double spread = MarketInfo(Symbol(), MODE_SPREAD);          // 修正後
```

### 4. 配列初期化エラー
```
エラー: array out of range
```
**対処法**:
```cpp
// 配列サイズを明示的に指定
double levels[];           // 修正前
double levels[10];         // 修正後
ArrayResize(levels, 10);   // または動的にリサイズ
```

---

## 📊 テスト用チェックリスト

### コンパイル後の初期テスト
- [ ] コンパイルエラーなし
- [ ] 警告メッセージの確認
- [ ] EAがナビゲーターに表示される
- [ ] チャートに適用可能

### 動作確認テスト
- [ ] 情報パネルが表示される
- [ ] エキスパートタブにエラーなし
- [ ] パラメータ変更が反映される
- [ ] 時間フィルターが機能する

### トレード機能テスト
- [ ] デモ口座で注文が出る
- [ ] 損切り/利確が設定される
- [ ] トレール機能が動作する
- [ ] 日次制限が機能する

---

## 🐛 デバッグ用コード追加位置

### 1. 初期化デバッグ（FX5MinScalpingEA.mq4）
```cpp
int OnInit() {
    Print("=== EA Initialization Start ===");
    Print("Account Balance: ", AccountBalance());
    Print("Account Currency: ", AccountCurrency());
    Print("Symbol: ", Symbol());
    Print("Spread: ", MarketInfo(Symbol(), MODE_SPREAD));
    
    // 既存の初期化コード
    
    Print("=== EA Initialization Complete ===");
    return(INIT_SUCCEEDED);
}
```

### 2. シグナルデバッグ（PatternBreakPlugin.mqh）
```cpp
bool GetSignal(SignalInfo &signal) {
    Print("Checking for Pattern Break signal...");
    Print("Current Price: ", iClose(NULL, 0, 0));
    Print("Buildup Valid: ", m_lastBuildup.isValid);
    
    // 既存のシグナルロジック
    
    if(signal.isValid) {
        Print("SIGNAL GENERATED: ", signal.setupName);
        Print("Entry: ", signal.entryPrice);
        Print("SL: ", signal.stopLoss);
        Print("TP: ", signal.takeProfit);
    }
    return signal.isValid;
}
```

---

## 📝 修正作業の記録方法

### Gitでの作業フロー
```bash
# 1. 新しいブランチを作成（修正用）
git checkout -b fix-mt4-compilation

# 2. 修正を実施
# エディタで修正

# 3. 変更を確認
git diff

# 4. コミット
git add -A
git commit -m "Fix MT4 compilation errors: [具体的な修正内容]"

# 5. プッシュ
git push origin fix-mt4-compilation

# 6. 元のブランチにマージ（テスト後）
git checkout fx-scalping-integration
git merge fix-mt4-compilation
git push origin fx-scalping-integration
```

---

## 💡 効率的な引き継ぎのコツ

### 1. エラーログの完全コピー
MT4のコンパイルエラーは**全文をコピー**してClaude Codeに伝える：
```
Experts\FX5MinScalpingEA.mq4(125,10): error 130: invalid stops
Include\FX5MinScalping\DataStructures.mqh(45,5): warning 31: variable not used
```

### 2. スクリーンショットの活用
- MetaEditorのエラー画面
- チャート上の表示異常
- エキスパートタブのログ

### 3. 段階的なテスト
1. まず**最小構成**でコンパイル（メインEAのみ）
2. 次に**1つずつ**プラグインを有効化
3. 最後に**全機能**を有効化

---

## 📚 ドキュメント優先順位

### 必ず最初に読むべき
1. **HANDOVER_GUIDE.md**（このファイル）
2. **PROJECT_COMPLETION_REPORT.md** - 実装内容の全体像
3. **CLAUDE.md** - プロジェクトコンテキスト

### エラー修正時に参照
1. **EA_ARCHITECTURE_DESIGN.md** - システム設計
2. **DATA_INTERFACE_SPECIFICATION.md** - データ仕様
3. **PLUGIN_DETAILED_DESIGN.md** - 各プラグインの詳細

### 動作確認時に参照
1. **TESTING_GUIDE.md** - テスト手順
2. **USER_MANUAL.md** - 期待される動作
3. **QUICK_START_GUIDE.md** - 基本的な使い方

---

## 🔄 継続的な改善

### バージョン管理
```
現在: v1.0.0（初回リリース）
次回: v1.0.1（MT4コンパイル修正）
将来: v1.1.0（機能追加）
```

### 修正履歴の記録
`docs/fx-scalping/CHANGELOG.md`を作成して記録：
```markdown
## [1.0.1] - 2025-08-XX
### Fixed
- MT4コンパイルエラー修正
- インクルードパスの調整
- [具体的な修正内容]

### Changed
- [変更内容]
```

---

## ⚠️ 重要な注意事項

### ファイルエンコーディング
- **必ずUTF-8**で保存
- 日本語コメントがある場合は特に注意
- MetaEditorのデフォルトはANSIなので変更必要

### パス区切り文字
- Windowsでも`/`を使用（MQL4は両方対応）
- 絶対パスは避ける
- 相対パスで記述

### MT4の制限事項
- 配列の動的確保に制限あり
- 文字列処理が特殊
- ファイルアクセスは`Files`フォルダのみ

---

## 🆘 トラブルシューティング連絡先

### GitHub
- リポジトリ: https://github.com/kapistock365/mt4-trading-tools
- Issues: バグ報告、質問
- Wiki: 追加ドキュメント

### ファイル構成の確認
```bash
# ファイル一覧を出力
find . -name "*.mq4" -o -name "*.mqh" | sort

# 行数確認
wc -l Include/FX5MinScalping/*.mqh

# 依存関係確認
grep -h "^#include" Include/FX5MinScalping/*.mqh | sort -u
```

---

## ✅ 引き継ぎ準備完了チェック

### リポジトリ側
- [x] 全ファイルがGitHubにプッシュ済み
- [x] ブランチ: fx-scalping-integration
- [x] ドキュメント完備
- [x] 設定ファイル同梱

### 引き継ぎ側で必要なもの
- [ ] Git環境
- [ ] MT4インストール済み
- [ ] デモ口座開設済み
- [ ] EUR/USD取引可能

### 推奨環境
- MT4 Build 1350以上
- Windows 10/11
- メモリ4GB以上
- 安定したインターネット接続

---

## 📌 クイックリファレンス

### 主要クラス/関数
```cpp
// EA初期化
int OnInit()

// ティック処理
void OnTick()

// シグナル取得
bool GetSignal(SignalInfo &signal)

// トレード実行
void ExecuteTrade(SignalInfo &signal)

// フィルターチェック
bool IsTradingAllowed()
```

### 重要パラメータ
```
MagicNumber: 20250825
DefaultLots: 0.01
StopLossPips: 10.0
TakeProfitPips: 20.0
MaxTradesPerDay: 5
```

---

*最終更新: 2025-08-25*
*次回更新: MT4コンパイル結果に基づく*