# 開発ガイドライン

> 📐 **アーキテクチャの詳細は[ARCHITECTURE.md](ARCHITECTURE.md)を参照**

## コーディング規約

### ファイル構成
```
/Experts        - EA（自動売買プログラム）
/Indicators     - インジケーター
/Scripts        - スクリプト
/Include        - 共通ライブラリ
/Files          - データファイル
```

### 命名規則
- **EA**: `XxxYyyEA.mq4` (例: TrendFollowEA.mq4)
- **インジケーター**: `XxxYyy.mq4` (例: TrendBreakout.mq4)
- **ライブラリ**: `XxxManager.mqh` (例: OrderManager.mqh)
- **関数**: `CalculateXxx()`, `CheckXxx()`, `UpdateXxx()`
- **変数**: キャメルケース (例: `stopLossDistance`)

### コメント規則
```mql4
//+------------------------------------------------------------------+
//| 関数の説明                                                        |
//+------------------------------------------------------------------+
```

## Git運用ルール

### ブランチ戦略
- `master`: 安定版
- `develop`: 開発版
- `feature/xxx`: 新機能開発
- `bugfix/xxx`: バグ修正

### コミットメッセージ
```
Add: 新機能追加
Fix: バグ修正
Update: 機能改善
Refactor: リファクタリング
Doc: ドキュメント更新
```

## テスト方法

### 1. ストラテジーテスター
- 期間: 最低6ヶ月
- スプレッド: ブローカーの実際の値
- モデル: 全ティック

### 2. デモ口座
- 最低2週間の運用
- 異なる相場状況でテスト
- エラーログの確認

### 3. 本番導入
- 最小ロットから開始
- 段階的にロットサイズを増加
- 日次でパフォーマンス確認

## 共通パラメータ

### リスク管理
- `MaxLossPerTrade`: 2.0 (%)
- `DailyMaxLoss`: 5.0 (%)
- `RiskRewardRatio`: 1:2以上

### トレーリングストップ
- `TrailStart`: 10.0 (pips)
- `TrailDistance`: 5.0 (pips)

### ロット計算
- `UseAutoLotSize`: true
- `RiskPercent`: 1.0-2.0 (%)

## トラブルシューティング

### よくあるエラー

1. **OrderSend error 130**
   - 原因: 無効なストップロス/テイクプロフィット
   - 対策: `MarketInfo(Symbol(), MODE_STOPLEVEL)`を確認

2. **OrderModify error 1**
   - 原因: 変更なしの注文変更
   - 対策: 現在の値と比較してから変更

3. **array out of range**
   - 原因: 配列の範囲外アクセス
   - 対策: `ArraySize()`でサイズ確認

### デバッグ方法

```mql4
// デバッグ出力
Print("デバッグ: 変数名=", 変数値);

// エラーチェック
if(GetLastError() != 0) {
    Print("エラー: ", GetLastError());
    ResetLastError();
}
```

## プラグイン開発

### 新規プラグインの作成手順

#### 1. プラグインクラスの作成

`Include/Plugins/`ディレクトリに新しいファイルを作成：

```mql4
// Include/Plugins/MyNewPlugin.mqh
#property copyright "Copyright 2025"
#property strict

#include "../PluginBase.mqh"

class CMyNewPlugin : public CPluginBase
{
private:
    // プラグイン固有の変数
    
public:
    // コンストラクタ
    CMyNewPlugin() : CPluginBase("MyNewPlugin", "1.0", "説明") {}
    
    // 必須メソッドの実装
    virtual bool OnInit() override {
        // 初期化処理
        return true;
    }
    
    virtual void OnDeinit() override {
        // 終了処理
    }
    
    virtual void OnTick() override {
        if(!IsEnabled()) return;
        // ティック処理
    }
};
```

#### 2. UnifiedTradingEAへの登録

```mql4
// Experts/UnifiedTradingEA.mq4のOnInit()に追加
#include "../Include/Plugins/MyNewPlugin.mqh"

// プラグインの登録
CMyNewPlugin* myPlugin = new CMyNewPlugin();
g_pluginManager.RegisterPlugin(myPlugin);
```

#### 3. GUI統合（オプション）

```mql4
virtual void CreateSettingsPanel(int &y) override {
    string prefix = "MNP_";  // プラグイン固有のプレフィックス
    
    CreateLabel(prefix + "Title", "【My Plugin設定】", 10, y);
    y += 20;
    
    // 設定項目を追加
}
```

### プラグイン開発のベストプラクティス

1. **独立性の維持**
   - 他のプラグインに依存しない
   - 共有リソースは最小限に

2. **エラーハンドリング**
   ```mql4
   if(エラー条件) {
       Print(m_name + ": エラーメッセージ");
       return;
   }
   ```

3. **設定の永続化**
   ```mql4
   virtual bool SaveSettings() override {
       // Files/プラグイン名.setに保存
   }
   ```

4. **リソース管理**
   - OnDeinit()で確実にリソースを解放
   - オブジェクトの削除を忘れない

### プラグイン間通信（計画中）

```mql4
// イベントの発行
PublishEvent("SIGNAL_DETECTED", データ);

// イベントの購読
SubscribeEvent("SIGNAL_DETECTED", OnSignalDetected);
```

## パフォーマンス最適化

1. **不要な計算を避ける**
   - OnTick()内で毎回計算しない
   - 静的変数やグローバル変数を活用

2. **オブジェクトの管理**
   - 使用後は必ず削除
   - 一意な名前を使用

3. **ファイルアクセス**
   - 最小限に抑える
   - バッファリングを使用