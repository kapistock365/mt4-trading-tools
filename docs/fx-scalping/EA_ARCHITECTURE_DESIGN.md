# FX 5分足スキャルピングEA - アーキテクチャ設計書

## 1. システム概要

### 1.1 目的
ボブ・ボルマンの5分足スキャルピング手法を自動化し、24時間稼働可能なEAとして実装する。

### 1.2 システム構成
```
┌─────────────────────────────────────────────┐
│           UnifiedTradingEA.mq4              │
│              （メインコントローラー）           │
└────────────────┬────────────────────────────┘
                 │
    ┌────────────┴────────────┬─────────────┬──────────────┐
    ▼                         ▼             ▼              ▼
┌──────────┐         ┌──────────┐  ┌──────────┐  ┌──────────┐
│ Order    │         │ Account  │  │ Market   │  │ Risk     │
│ Manager  │         │ Manager  │  │ Analyzer │  │ Manager  │
└──────────┘         └──────────┘  └──────────┘  └──────────┘
                              │
                 ┌────────────┴────────────┬─────────────┐
                 ▼                         ▼             ▼
          ┌──────────────┐      ┌──────────────┐ ┌──────────────┐
          │Pattern Break │      │PB Pullback   │ │PB Combo      │
          │Plugin        │      │Plugin        │ │Plugin        │
          └──────────────┘      └──────────────┘ └──────────────┘
```

### 1.3 モジュール構成
```
MQL4/
├── Experts/
│   └── FX5MinScalpingEA.mq4          # メインEA
├── Include/
│   ├── Core/
│   │   ├── OrderManager.mqh          # 注文管理
│   │   ├── AccountManager.mqh        # 口座管理
│   │   ├── MarketAnalyzer.mqh        # 市場分析
│   │   └── RiskManager.mqh           # リスク管理
│   ├── Plugins/
│   │   ├── PluginBase.mqh            # プラグイン基底クラス
│   │   ├── PatternBreakPlugin.mqh    # パターンブレイク
│   │   ├── PBPullbackPlugin.mqh      # プルバック
│   │   ├── PBComboPlugin.mqh         # コンビ
│   │   ├── TimeFilterPlugin.mqh      # 時間フィルター
│   │   └── SpreadFilterPlugin.mqh    # スプレッドフィルター
│   ├── Indicators/
│   │   ├── BuildupDetector.mqh       # ビルドアップ検出
│   │   ├── PatternRecognizer.mqh     # パターン認識
│   │   └── PriceActionAnalyzer.mqh   # プライスアクション分析
│   └── Utils/
│       ├── Logger.mqh                # ログ出力
│       ├── Statistics.mqh            # 統計処理
│       └── Helpers.mqh               # ヘルパー関数
└── Libraries/
    └── FX5MinScalpingLib.mq4         # 共通ライブラリ
```

## 2. コアモジュール詳細設計

### 2.1 OrderManager（注文管理）
```cpp
class COrderManager {
private:
    int m_magicNumber;           // EA識別番号
    int m_maxRetries;             // 最大リトライ回数
    double m_slippage;            // スリッページ許容値
    
public:
    // 基本注文機能
    int OpenOrder(int type, double lots, double price, 
                  double sl, double tp, string comment);
    bool CloseOrder(int ticket, double lots = 0);
    bool ModifyOrder(int ticket, double sl, double tp);
    
    // 高度な機能
    bool PartialClose(int ticket, double percent);
    bool TrailingStop(int ticket, double distance, double step);
    bool BreakEven(int ticket, double triggerProfit);
    
    // ポジション管理
    int GetOpenPositions(int &tickets[]);
    double GetPositionProfit(int ticket);
    bool IsPositionOpen(int ticket);
    
    // エラーハンドリング
    bool RetryOperation(int operation, int maxRetries);
    string GetLastError();
};
```

### 2.2 AccountManager（口座管理）
```cpp
class CAccountManager {
private:
    double m_riskPercent;         // リスク割合
    double m_maxDailyLoss;        // 日次最大損失
    double m_maxDrawdown;         // 最大DD
    
public:
    // ロット計算
    double CalculateLotSize(double stopLossPips);
    double GetOptimalLotSize(double riskPercent, double slPips);
    
    // 資金管理
    double GetAccountEquity();
    double GetAccountBalance();
    double GetDailyPnL();
    double GetCurrentDrawdown();
    
    // リスクチェック
    bool CanTrade();
    bool CheckDailyLossLimit();
    bool CheckDrawdownLimit();
    
    // パフォーマンス追跡
    void UpdateStatistics();
    double GetWinRate();
    double GetProfitFactor();
};
```

### 2.3 MarketAnalyzer（市場分析）
```cpp
class CMarketAnalyzer {
private:
    int m_timeframe;              // 分析時間軸
    int m_lookbackPeriod;         // 過去参照期間
    
public:
    // トレンド分析
    int GetTrendDirection();      // 1:上昇, -1:下降, 0:レンジ
    double GetTrendStrength();     // 0.0-1.0
    bool IsTrending();
    
    // サポート/レジスタンス
    double GetNearestSupport();
    double GetNearestResistance();
    bool IsNearKeyLevel(double price, double distance);
    
    // ボラティリティ
    double GetATR(int period);
    double GetCurrentVolatility();
    bool IsVolatilityNormal();
    
    // プライスアクション
    bool IsBuildup(int startBar, int endBar);
    bool IsFalseBreak(int bar);
    bool IsTeaseBreak(int bar);
    
    // 25EMA関連
    double GetEMA(int period, int shift);
    double GetDistanceFromEMA(double price);
    bool IsPriceAboveEMA();
};
```

### 2.4 RiskManager（リスク管理）
```cpp
class CRiskManager {
private:
    double m_maxRiskPerTrade;     // 1トレード最大リスク
    int m_maxConcurrentTrades;    // 最大同時ポジション
    double m_maxDailyLoss;        // 日次最大損失
    
public:
    // リスク計算
    double CalculateRisk(double lotSize, double slPips);
    bool ValidateRisk(double proposedRisk);
    
    // ポジション管理
    bool CanOpenNewPosition();
    int GetCurrentPositionCount();
    double GetTotalExposure();
    
    // 損失管理
    void OnStopLossHit(double loss);
    bool ShouldStopTrading();
    void ResetDailyCounters();
    
    // 緊急停止
    bool EmergencyStopCheck();
    void CloseAllPositions(string reason);
};
```

## 3. プラグインシステム設計

### 3.1 プラグイン基底クラス
```cpp
class CPluginBase {
protected:
    string m_name;                // プラグイン名
    bool m_enabled;               // 有効/無効
    int m_priority;               // 実行優先度
    
    // 依存モジュール参照
    COrderManager* m_orderManager;
    CAccountManager* m_accountManager;
    CMarketAnalyzer* m_marketAnalyzer;
    CRiskManager* m_riskManager;
    
public:
    // ライフサイクル
    virtual bool OnInit() = 0;
    virtual void OnDeinit() = 0;
    virtual void OnTick() = 0;
    virtual void OnTimer() = 0;
    
    // シグナル生成
    virtual int GetSignal() = 0;  // 1:買い, -1:売り, 0:なし
    virtual bool ValidateEntry() = 0;
    virtual bool ValidateExit() = 0;
    
    // パラメータ管理
    virtual void SetParameters(string params) = 0;
    virtual string GetParameters() = 0;
    
    // 状態管理
    void Enable() { m_enabled = true; }
    void Disable() { m_enabled = false; }
    bool IsEnabled() { return m_enabled; }
};
```

### 3.2 PatternBreakPlugin（パターンブレイク）
```cpp
class CPatternBreakPlugin : public CPluginBase {
private:
    // パラメータ
    int m_buildupBars;            // ビルドアップ判定バー数
    double m_breakoutBuffer;      // ブレイク判定ピップス
    double m_maxEMADistance;      // EMAからの最大距離
    
    // 内部状態
    double m_patternHigh;         // パターン上限
    double m_patternLow;          // パターン下限
    datetime m_buildupStart;      // ビルドアップ開始時刻
    
public:
    // シグナル検出
    virtual int GetSignal() override {
        if (!m_enabled) return 0;
        
        // 1. パターン識別
        if (!IdentifyPattern()) return 0;
        
        // 2. ビルドアップ確認
        if (!CheckBuildup()) return 0;
        
        // 3. ブレイク判定
        int breakDirection = CheckBreakout();
        if (breakDirection == 0) return 0;
        
        // 4. フィルター適用
        if (!ApplyFilters(breakDirection)) return 0;
        
        return breakDirection;
    }
    
private:
    bool IdentifyPattern();
    bool CheckBuildup();
    int CheckBreakout();
    bool ApplyFilters(int direction);
    
    // パターン認識
    bool IsRangePattern();
    bool IsTrianglePattern();
    bool IsFlagPattern();
    
    // ビルドアップ分析
    int CountBuildupBars();
    double GetBuildupRange();
    bool IsBuildupValid();
};
```

### 3.3 PBPullbackPlugin（プルバック）
```cpp
class CPBPullbackPlugin : public CPluginBase {
private:
    // パラメータ
    double m_pullbackMinDepth;    // 最小プルバック深さ
    double m_pullbackMaxDepth;    // 最大プルバック深さ
    int m_maxPullbackBars;        // プルバック最大期間
    
    // 内部状態
    int m_originalBreakDirection;  // 元のブレイク方向
    double m_breakLevel;           // ブレイクレベル
    datetime m_breakTime;          // ブレイク時刻
    
public:
    virtual int GetSignal() override {
        if (!m_enabled) return 0;
        
        // 1. 初回ブレイクの追跡
        if (!TrackInitialBreak()) return 0;
        
        // 2. プルバック検出
        if (!DetectPullback()) return 0;
        
        // 3. 反転シグナル確認
        if (!CheckReversal()) return 0;
        
        // 4. エントリー条件確認
        if (!ValidateEntry()) return 0;
        
        return m_originalBreakDirection;
    }
    
private:
    bool TrackInitialBreak();
    bool DetectPullback();
    bool CheckReversal();
    
    // プルバック分析
    double GetPullbackDepth();
    bool IsPullbackComplete();
    bool IsRetestSuccessful();
    
    // 反転パターン
    bool IsPinBar();
    bool IsEngulfing();
    bool IsInsideBarBreak();
};
```

## 4. データ構造定義

### 4.1 トレード情報
```cpp
struct TradeInfo {
    int ticket;                   // チケット番号
    int type;                     // 注文タイプ
    double openPrice;             // エントリー価格
    double stopLoss;              // 損切り価格
    double takeProfit;            // 利確価格
    double lotSize;               // ロットサイズ
    datetime openTime;            // エントリー時刻
    string setupType;             // セットアップ種類
    string comment;               // コメント
};
```

### 4.2 市場状態
```cpp
struct MarketState {
    int trend;                    // トレンド方向
    double trendStrength;         // トレンド強度
    double volatility;            // ボラティリティ
    double spread;                // スプレッド
    double emaValue;              // 25EMA値
    double nearestSupport;        // 直近サポート
    double nearestResistance;     // 直近レジスタンス
    bool isBuildup;               // ビルドアップ中
    bool isLondonSession;         // ロンドン時間
    bool isNYSession;             // NY時間
};
```

### 4.3 パフォーマンス統計
```cpp
struct PerformanceStats {
    int totalTrades;              // 総トレード数
    int winTrades;                // 勝ちトレード数
    int lossTrades;               // 負けトレード数
    double totalProfit;           // 総利益
    double totalLoss;             // 総損失
    double maxDrawdown;           // 最大DD
    double winRate;               // 勝率
    double profitFactor;          // PF
    double averageWin;            // 平均利益
    double averageLoss;           // 平均損失
    datetime lastUpdate;          // 最終更新
};
```

## 5. イベント処理フロー

### 5.1 OnInit（初期化）
```
1. 設定ファイル読み込み
2. 各モジュール初期化
   - OrderManager
   - AccountManager
   - MarketAnalyzer
   - RiskManager
3. プラグイン登録・初期化
   - PatternBreakPlugin
   - PBPullbackPlugin
   - PBComboPlugin
   - TimeFilterPlugin
   - SpreadFilterPlugin
4. チャート設定
   - 25EMA追加
   - カスタムインジケーター設定
5. ログシステム起動
6. 初期状態チェック
```

### 5.2 OnTick（ティック処理）
```
1. 新規バー確認
   if (!IsNewBar()) return;
   
2. 市場状態更新
   MarketAnalyzer.UpdateState();
   
3. リスクチェック
   if (!RiskManager.CanTrade()) return;
   
4. 既存ポジション管理
   ManageOpenPositions();
   
5. 各プラグインでシグナル生成
   foreach (Plugin in Plugins) {
       signal = Plugin.GetSignal();
       if (signal != 0) break;
   }
   
6. エントリー実行
   if (signal != 0) {
       ExecuteEntry(signal);
   }
   
7. 統計更新
   UpdateStatistics();
```

### 5.3 OnTimer（定期処理）
```
1. パフォーマンス記録（1分毎）
2. リスク状態チェック（5分毎）
3. 日次リセット（日本時間6:00）
4. ログローテーション（1時間毎）
5. 設定再読み込み（30分毎）
```

## 6. エラーハンドリング

### 6.1 エラー分類
```cpp
enum ErrorLevel {
    ERROR_INFO,      // 情報レベル
    ERROR_WARNING,   // 警告レベル
    ERROR_CRITICAL,  // 重大エラー
    ERROR_FATAL      // 致命的エラー
};
```

### 6.2 エラー処理フロー
```
1. エラー検出
2. エラーレベル判定
3. ログ記録
4. リトライ判定
   - INFO/WARNING: 処理継続
   - CRITICAL: リトライ後継続
   - FATAL: EA停止
5. 通知送信（CRITICAL以上）
6. リカバリー処理
```

### 6.3 一般的なエラーと対処
```cpp
// 注文エラー
case ERR_TRADE_CONTEXT_BUSY:
    Sleep(1000);
    RetryOperation();
    break;
    
case ERR_REQUOTE:
    RefreshRates();
    AdjustPrice();
    RetryOperation();
    break;
    
case ERR_NOT_ENOUGH_MONEY:
    LogError("Insufficient margin");
    SkipTrade();
    break;
    
// 接続エラー
case ERR_NO_CONNECTION:
    WaitForConnection();
    ResyncState();
    break;
```

## 7. パフォーマンス最適化

### 7.1 処理効率化
- バー確定時のみ処理（ティック毎は避ける）
- 計算結果のキャッシュ活用
- 不要な履歴データ参照を削減
- 配列の事前確保

### 7.2 メモリ管理
- 動的配列の適切な解放
- 文字列連結の最小化
- オブジェクトの再利用
- 定期的なガベージコレクション

### 7.3 並行処理考慮
- 複数通貨ペア対応時の排他制御
- グローバル変数のアクセス制御
- ファイルI/Oの同期

## 8. セキュリティ考慮事項

### 8.1 認証・認可
- マジックナンバーによるEA識別
- ブローカー制限チェック
- ライセンス認証（必要に応じて）

### 8.2 データ保護
- 設定ファイルの暗号化
- ログファイルの難読化
- 通信データの検証

### 8.3 異常動作防止
- 最大ポジション数制限
- 連続エントリー防止
- 異常値フィルタリング
- 緊急停止機能

## 9. テスト戦略

### 9.1 単体テスト
- 各モジュールの個別テスト
- 境界値テスト
- エラー処理テスト

### 9.2 統合テスト
- モジュール間連携テスト
- シナリオベーステスト
- ストレステスト

### 9.3 バックテスト
- 過去データでの検証
- パラメータ最適化
- ウォークフォワード分析

### 9.4 フォワードテスト
- デモ口座での実行
- リアルタイム監視
- パフォーマンス測定

---
*作成日: 2025-08-25*
*バージョン: 1.0*