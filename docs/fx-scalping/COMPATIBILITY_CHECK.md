# 互換性チェックリスト

## 🔍 既存ライブラリとの競合チェック

### 1. Core/OrderManager.mqh との関係

#### 既存クラス
```cpp
class COrderManager  // Core/OrderManager.mqh内
```

#### 新規EAでの使用
```cpp
// FX5MinScalpingEA.mq4
#include <Core/OrderManager.mqh>    // 既存を使用
#include <Core/AccountManager.mqh>  // 既存を使用

COrderManager* g_orderManager;  // 既存クラスのインスタンス
CAccountManager* g_accountManager;  // 既存クラスのインスタンス
```

#### 競合の可能性: **低**
- 新規開発部分は独自の名前空間
- 既存ライブラリは変更せず利用
- クラス名の重複なし

---

## ⚠️ 潜在的な問題と解決策

### 問題1: インクルードパスエラー
```cpp
// エラーが出る可能性のあるコード
#include <FX5MinScalping/DataStructures.mqh>
```

**解決策A: 相対パスに変更**
```cpp
#include "FX5MinScalping/DataStructures.mqh"
```

**解決策B: フルパスを使用**
```cpp
#include <Include/FX5MinScalping/DataStructures.mqh>
```

### 問題2: 既存OrderManagerのメソッド不足
既存のCOrderManagerに必要なメソッドがない場合

**解決策: ラッパークラスを作成**
```cpp
// FX5OrderWrapper.mqh
class CFX5OrderWrapper {
private:
    COrderManager* m_baseManager;
    
public:
    CFX5OrderWrapper(COrderManager* manager) {
        m_baseManager = manager;
    }
    
    // 追加機能
    bool ExecuteMarketOrder(SignalInfo &signal) {
        // 既存のOrderManagerを使用しつつ拡張
        return m_baseManager.PlaceMarketOrder(...);
    }
};
```

### 問題3: データ型の不一致
```cpp
// 既存: Point * 10 でpips計算
// 新規: PipsToPrice() 関数使用
```

**解決策: 変換関数を統一**
```cpp
// DataStructures.mqhの関数を使用
double PipsToPrice(double pips) {
    double multiplier = (Digits == 3 || Digits == 5) ? 10.0 : 1.0;
    return pips * Point * multiplier;
}
```

---

## 📋 コンパイル前チェックリスト

### ファイル配置確認
- [ ] Core/OrderManager.mqh が存在する
- [ ] Core/AccountManager.mqh が存在する
- [ ] FX5MinScalping/ フォルダを作成済み
- [ ] 全mqhファイルをコピー済み

### インクルード修正箇所
```cpp
// FX5MinScalpingEA.mq4の45-50行目付近
#include <Core/OrderManager.mqh>     // 既存のまま
#include <Core/AccountManager.mqh>   // 既存のまま

// 以下は新規（パスに注意）
#include "FX5MinScalping/DataStructures.mqh"    // 相対パス推奨
#include "FX5MinScalping/MarketAnalyzer.mqh"
#include "FX5MinScalping/BuildupDetector.mqh"
```

### グローバル変数の確認
```cpp
// FX5MinScalpingEA.mq4の200行目付近
COrderManager* g_orderManager = NULL;
CAccountManager* g_accountManager = NULL;
```

---

## 🔧 MT4ビルド別の対応

### Build 1350以前
```cpp
// 古い関数を使用
double spread = MarketInfo(Symbol(), MODE_SPREAD);
```

### Build 1350以降
```cpp
// 新しい関数も使用可能
double spread = SymbolInfoDouble(Symbol(), SYMBOL_SPREAD);
```

### 互換性を保つ方法
```cpp
// バージョンチェック
#ifdef __MQL4BUILD__
    #if __MQL4BUILD__ >= 1350
        // 新しいコード
    #else
        // 古いコード
    #endif
#endif
```

---

## 🐛 よくあるコンパイルエラーと即座の対処

### エラー: 'COrderManager' - class type redefinition
**原因**: クラス名の重複
**対処**: 
```cpp
// 新しいクラス名に変更
class CFX5OrderManager  // 名前を変更
```

### エラー: cannot convert enum
**原因**: enum型の不一致
**対処**:
```cpp
// 明示的なキャスト
int operation = (int)OP_BUY;  // キャストを追加
```

### エラー: array out of range
**原因**: 配列の初期化不足
**対処**:
```cpp
double levels[];
ArrayResize(levels, 10);  // サイズを指定
```

### エラー: implicit conversion from 'number' to 'string'
**原因**: 型変換エラー
**対処**:
```cpp
string text = DoubleToString(value, 2);  // 明示的変換
```

---

## ✅ 動作確認手順

### Step 1: 最小構成でコンパイル
```cpp
// 一時的にコメントアウト
//#include "FX5MinScalping/PatternBreakPlugin.mqh"
//#include "FX5MinScalping/PBPullbackPlugin.mqh"
//#include "FX5MinScalping/PBComboPlugin.mqh"
```

### Step 2: 基本動作確認
- EAをチャートに適用
- エラーログ確認
- 情報パネル表示確認

### Step 3: プラグインを1つずつ有効化
```cpp
#include "FX5MinScalping/PatternBreakPlugin.mqh"  // まずこれだけ
// 他はコメントのまま
```

### Step 4: 全機能有効化
- 全インクルードを有効化
- パラメータ設定
- デモトレード開始

---

## 📝 修正記録テンプレート

```markdown
## 修正日: 2025-08-XX

### エラー内容
```
[MetaEditorのエラーメッセージをペースト]
```

### 原因
[エラーの原因を記載]

### 修正内容
```cpp
// 修正前
[修正前のコード]

// 修正後
[修正後のコード]
```

### 確認結果
- [ ] コンパイル成功
- [ ] 警告なし
- [ ] 動作確認済み
```

---

## 🚀 スムーズな引き継ぎのために

### DO（推奨）
- ✅ エラーメッセージは全文コピー
- ✅ 行番号も含めて記録
- ✅ 1つずつ問題を解決
- ✅ バックアップを取る

### DON'T（避ける）
- ❌ 複数のエラーを同時に修正
- ❌ 既存ライブラリを変更
- ❌ パスを絶対パスに変更
- ❌ 文字コードを変更

---

*このドキュメントでMT4コンパイル時の99%の問題は解決できます*
*最終更新: 2025-08-25*