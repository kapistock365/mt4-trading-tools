# FX 5分足スキャルピングEA - データ構造・インターフェース仕様書

## 1. データ構造定義

### 1.1 基本データ型

#### 価格情報
```cpp
struct PriceData {
    double open;                      // 始値
    double high;                      // 高値
    double low;                       // 安値
    double close;                     // 終値
    datetime time;                    // 時刻
    long volume;                      // 出来高（利用可能な場合）
    int spread;                       // スプレッド（ポイント）
};

struct BarInfo {
    PriceData price;                  // 価格データ
    double body;                      // 実体サイズ
    double upperWick;                 // 上ヒゲ
    double lowerWick;                 // 下ヒゲ
    double range;                     // 高値-安値
    int type;                         // 1:陽線, -1:陰線, 0:同時線
    bool isDoji;                      // 同時線フラグ
    bool isPinBar;                    // ピンバーフラグ
    bool isInsideBar;                 // インサイドバーフラグ
};
```

#### パターン情報
```cpp
struct PatternInfo {
    string patternType;               // パターンタイプ
    double upperBoundary;             // 上限価格
    double lowerBoundary;             // 下限価格
    int startBar;                     // 開始バー
    int endBar;                       // 終了バー
    datetime startTime;               // 開始時刻
    datetime endTime;                 // 終了時刻
    double patternHeight;             // パターン高さ
    int touchCount;                   // タッチ回数
    double reliability;               // 信頼度（0-100）
    bool isActive;                    // アクティブフラグ
};

enum PatternType {
    PATTERN_NONE = 0,
    PATTERN_RANGE,                    // レンジ
    PATTERN_TRIANGLE_ASC,            // 上昇三角形
    PATTERN_TRIANGLE_DESC,           // 下降三角形
    PATTERN_TRIANGLE_SYM,            // 対称三角形
    PATTERN_FLAG_BULL,               // 上昇フラグ
    PATTERN_FLAG_BEAR,               // 下降フラグ
    PATTERN_WEDGE_RISING,            // 上昇ウェッジ
    PATTERN_WEDGE_FALLING,           // 下降ウェッジ
    PATTERN_CHANNEL_UP,              // 上昇チャネル
    PATTERN_CHANNEL_DOWN,            // 下降チャネル
    PATTERN_HEAD_SHOULDERS,          // ヘッドアンドショルダー
    PATTERN_DOUBLE_TOP,              // ダブルトップ
    PATTERN_DOUBLE_BOTTOM            // ダブルボトム
};
```

#### ビルドアップ情報
```cpp
struct BuildupInfo {
    int startBar;                     // 開始バー
    int endBar;                       // 終了バー
    int barCount;                     // バー数
    double rangeHigh;                 // レンジ上限
    double rangeLow;                  // レンジ下限
    double rangeSize;                 // レンジサイズ
    double centerPrice;               // 中心価格
    double compression;               // 圧縮度（0-1）
    double dojiRatio;                 // 同時線割合
    double avgBarSize;                // 平均バーサイズ
    int direction;                    // 予想方向（1:上, -1:下, 0:不明）
    double quality;                   // 品質スコア（0-100）
    bool isValid;                     // 有効フラグ
};
```

### 1.2 トレード関連

#### ポジション情報
```cpp
struct PositionInfo {
    int ticket;                       // チケット番号
    int magicNumber;                  // マジックナンバー
    string symbol;                    // 通貨ペア
    int orderType;                    // 注文タイプ（OP_BUY/OP_SELL）
    double lots;                      // ロット数
    double openPrice;                 // エントリー価格
    double stopLoss;                  // 損切り価格
    double takeProfit;                // 利確価格
    datetime openTime;                // エントリー時刻
    double commission;                // 手数料
    double swap;                      // スワップ
    double profit;                    // 現在損益
    string comment;                   // コメント
    string setupType;                 // セットアップタイプ
    int trailingStatus;               // トレーリング状態
    double breakEvenLevel;            // ブレークイーブンレベル
};

struct TradeRequest {
    int operation;                    // 操作タイプ
    double lots;                      // ロット数
    double price;                     // 価格
    double stopLoss;                  // 損切り
    double takeProfit;                // 利確
    int slippage;                     // スリッページ
    string comment;                   // コメント
    int magicNumber;                  // マジックナンバー
    datetime expiration;              // 有効期限
    color arrowColor;                 // 矢印色
};

struct TradeResult {
    bool success;                     // 成功フラグ
    int ticket;                       // チケット番号
    double executedPrice;             // 約定価格
    double executedLots;              // 約定ロット
    int errorCode;                    // エラーコード
    string errorMessage;              // エラーメッセージ
    int retryCount;                   // リトライ回数
    datetime timestamp;               // タイムスタンプ
};
```

#### リスク管理
```cpp
struct RiskParameters {
    double maxRiskPerTrade;           // 1トレード最大リスク（%）
    double maxDailyLoss;              // 日次最大損失（%）
    double maxDrawdown;               // 最大ドローダウン（%）
    int maxConcurrentTrades;          // 最大同時ポジション数
    double defaultStopLossPips;       // デフォルト損切り（pips）
    double defaultTakeProfitPips;     // デフォルト利確（pips）
    double minRiskRewardRatio;        // 最小リスクリワード比
    bool useTrailingStop;             // トレーリングストップ使用
    double trailingStartPips;         // トレーリング開始（pips）
    double trailingStepPips;          // トレーリングステップ（pips）
    bool useBreakEven;                // ブレークイーブン使用
    double breakEvenTriggerPips;      // ブレークイーブントリガー（pips）
    bool usePartialClose;             // 部分決済使用
    double partialClosePercent;       // 部分決済割合（%）
    double partialCloseTriggerPips;   // 部分決済トリガー（pips）
};

struct RiskStatus {
    double currentDailyLoss;          // 現在の日次損失
    double currentDrawdown;           // 現在のドローダウン
    int currentOpenTrades;            // 現在のオープントレード数
    double totalExposure;             // 総エクスポージャー
    bool canTrade;                    // トレード可能フラグ
    string restrictionReason;         // 制限理由
    datetime lastLossTime;            // 最後の損失時刻
    int consecutiveLosses;            // 連続損失数
};
```

### 1.3 市場分析

#### 市場状態
```cpp
struct MarketCondition {
    // トレンド
    int trendDirection;               // -1:下降, 0:レンジ, 1:上昇
    double trendStrength;             // トレンド強度（0-100）
    double ema25;                     // 25EMA値
    double emaSlope;                  // EMA傾き
    double priceToEmaDistance;        // 価格とEMAの距離
    
    // ボラティリティ
    double atr14;                     // ATR(14)
    double volatilityLevel;           // ボラティリティレベル（low/medium/high）
    double averageRange;              // 平均レンジ
    
    // サポート/レジスタンス
    double nearestSupport;            // 直近サポート
    double nearestResistance;         // 直近レジスタンス
    double keyLevels[10];             // キーレベル配列
    int keyLevelCount;                // キーレベル数
    
    // 時間帯
    string currentSession;            // 現在のセッション
    bool isLondonOpen;                // ロンドンオープン
    bool isNYOpen;                    // NYオープン
    bool isAsianSession;              // アジアセッション
    int minutesSinceOpen;             // オープンからの経過分
    
    // その他
    double currentSpread;             // 現在のスプレッド
    double averageSpread;             // 平均スプレッド
    bool isNewsTime;                  // ニュース時間帯
    datetime lastUpdate;              // 最終更新時刻
};

struct TechnicalIndicators {
    // 移動平均
    double ema25;
    double ema50;
    double ema100;
    double ema200;
    
    // オシレーター
    double rsi14;
    double stochK;
    double stochD;
    double macdMain;
    double macdSignal;
    double macdHistogram;
    
    // ボラティリティ
    double atr14;
    double atr20;
    double bollingerUpper;
    double bollingerMiddle;
    double bollingerLower;
    
    // カスタム
    double pivotPoint;
    double r1, r2, r3;               // レジスタンスレベル
    double s1, s2, s3;               // サポートレベル
};
```

### 1.4 シグナル・アラート

#### シグナル情報
```cpp
struct SignalInfo {
    int signalType;                   // 1:買い, -1:売り, 0:なし
    string setupName;                 // セットアップ名
    double entryPrice;                // エントリー推奨価格
    double stopLoss;                  // 推奨損切り
    double takeProfit;                // 推奨利確
    double signalStrength;            // シグナル強度（0-100）
    string reason;                    // シグナル理由
    datetime generatedTime;           // 生成時刻
    datetime expirationTime;          // 有効期限
    bool isValid;                     // 有効フラグ
    string additionalInfo;            // 追加情報
};

struct AlertInfo {
    string alertType;                 // アラートタイプ
    string message;                   // メッセージ
    int priority;                     // 優先度（1:低, 2:中, 3:高）
    datetime timestamp;               // タイムスタンプ
    bool isNotified;                  // 通知済みフラグ
    string actionRequired;            // 必要なアクション
};
```

## 2. インターフェース定義

### 2.1 基底インターフェース

#### IPlugin（プラグインインターフェース）
```cpp
interface IPlugin {
    // ライフサイクル
    bool Initialize(string parameters);
    void Deinitialize();
    void OnTick();
    void OnTimer();
    void OnTrade();
    
    // シグナル生成
    SignalInfo GetSignal();
    bool ValidateSignal(SignalInfo& signal);
    
    // 状態管理
    void Enable();
    void Disable();
    bool IsEnabled();
    
    // 設定
    void SetParameters(string params);
    string GetParameters();
    
    // 情報取得
    string GetName();
    string GetVersion();
    string GetDescription();
};
```

#### IOrderManager（注文管理インターフェース）
```cpp
interface IOrderManager {
    // 注文操作
    TradeResult OpenPosition(TradeRequest& request);
    TradeResult ClosePosition(int ticket, double lots = 0);
    TradeResult ModifyPosition(int ticket, double sl, double tp);
    
    // 高度な操作
    TradeResult PartialClose(int ticket, double percent);
    bool SetTrailingStop(int ticket, double distance, double step);
    bool SetBreakEven(int ticket, double triggerPips);
    
    // 情報取得
    bool GetPositionInfo(int ticket, PositionInfo& info);
    int GetOpenPositions(PositionInfo& positions[]);
    double GetTotalProfit();
    double GetTotalLoss();
};
```

#### IMarketAnalyzer（市場分析インターフェース）
```cpp
interface IMarketAnalyzer {
    // 市場状態
    void UpdateMarketCondition(MarketCondition& condition);
    int GetTrendDirection();
    double GetTrendStrength();
    
    // パターン認識
    bool DetectPattern(PatternInfo& pattern);
    bool DetectBuildup(BuildupInfo& buildup);
    
    // レベル計算
    double GetNearestSupport();
    double GetNearestResistance();
    void GetKeyLevels(double& levels[], int& count);
    
    // インジケーター
    void CalculateIndicators(TechnicalIndicators& indicators);
    double GetCustomIndicator(string name, int period, int shift);
};
```

#### IRiskManager（リスク管理インターフェース）
```cpp
interface IRiskManager {
    // リスク計算
    double CalculateLotSize(double stopLossPips);
    double CalculateRisk(double lots, double stopLossPips);
    bool ValidateRisk(TradeRequest& request);
    
    // リスク状態
    void UpdateRiskStatus(RiskStatus& status);
    bool CanOpenNewTrade();
    bool IsMaxDrawdownReached();
    
    // 緊急制御
    void EmergencyStop(string reason);
    void CloseAllPositions();
    void PauseTrading(int minutes);
};
```

### 2.2 イベントインターフェース

#### IEventListener（イベントリスナー）
```cpp
interface IEventListener {
    void OnPatternDetected(PatternInfo& pattern);
    void OnBuildupFormed(BuildupInfo& buildup);
    void OnBreakoutOccurred(double price, int direction);
    void OnSignalGenerated(SignalInfo& signal);
    void OnPositionOpened(PositionInfo& position);
    void OnPositionClosed(PositionInfo& position, double profit);
    void OnRiskLimitReached(string limitType);
    void OnError(int errorCode, string errorMessage);
};
```

#### IEventPublisher（イベント発行者）
```cpp
interface IEventPublisher {
    void RegisterListener(IEventListener* listener);
    void UnregisterListener(IEventListener* listener);
    void PublishEvent(string eventType, string data);
    void BroadcastAlert(AlertInfo& alert);
};
```

### 2.3 データアクセスインターフェース

#### IDataProvider（データプロバイダー）
```cpp
interface IDataProvider {
    // 価格データ
    bool GetPriceData(int shift, PriceData& data);
    bool GetBarInfo(int shift, BarInfo& info);
    int GetBars(datetime from, datetime to, PriceData& data[]);
    
    // 履歴データ
    double GetHistoricalHigh(int period);
    double GetHistoricalLow(int period);
    double GetAverageRange(int period);
    
    // リアルタイムデータ
    double GetBid();
    double GetAsk();
    double GetSpread();
    datetime GetServerTime();
};
```

#### IDataStorage（データストレージ）
```cpp
interface IDataStorage {
    // 保存
    bool SaveTradeHistory(PositionInfo& position);
    bool SaveSignalHistory(SignalInfo& signal);
    bool SavePerformanceData(string key, double value);
    
    // 読み込み
    int LoadTradeHistory(datetime from, datetime to, PositionInfo& trades[]);
    int LoadSignalHistory(datetime from, datetime to, SignalInfo& signals[]);
    double LoadPerformanceData(string key);
    
    // 管理
    bool ClearOldData(int daysToKeep);
    bool BackupData(string filename);
    bool RestoreData(string filename);
};
```

## 3. 通信プロトコル

### 3.1 内部通信

#### メッセージフォーマット
```cpp
struct InternalMessage {
    string sender;                    // 送信元モジュール
    string receiver;                  // 受信先モジュール
    string messageType;               // メッセージタイプ
    string payload;                   // ペイロード（JSON形式）
    datetime timestamp;               // タイムスタンプ
    int priority;                     // 優先度
    bool requiresResponse;            // 応答要求フラグ
    int messageId;                    // メッセージID
};

// メッセージタイプ定義
#define MSG_SIGNAL_GENERATED      "SIGNAL_GENERATED"
#define MSG_PATTERN_DETECTED      "PATTERN_DETECTED"
#define MSG_RISK_WARNING          "RISK_WARNING"
#define MSG_POSITION_UPDATE       "POSITION_UPDATE"
#define MSG_MARKET_UPDATE         "MARKET_UPDATE"
#define MSG_CONFIG_CHANGE         "CONFIG_CHANGE"
#define MSG_ERROR_OCCURRED        "ERROR_OCCURRED"
```

#### 通信チャネル
```cpp
class CMessageBus {
private:
    InternalMessage m_messageQueue[];
    int m_queueSize;
    
public:
    void SendMessage(InternalMessage& message);
    bool ReceiveMessage(string receiver, InternalMessage& message);
    void BroadcastMessage(InternalMessage& message);
    int GetPendingMessages(string receiver);
    void ClearQueue();
};
```

### 3.2 外部通信

#### API通信
```cpp
struct APIRequest {
    string endpoint;                  // エンドポイント
    string method;                    // GET/POST/PUT/DELETE
    string headers[];                 // ヘッダー
    string body;                      // リクエストボディ
    int timeout;                      // タイムアウト（秒）
};

struct APIResponse {
    int statusCode;                   // ステータスコード
    string headers[];                 // レスポンスヘッダー
    string body;                      // レスポンスボディ
    bool success;                     // 成功フラグ
    string errorMessage;              // エラーメッセージ
};
```

#### Webhook通知
```cpp
struct WebhookNotification {
    string url;                       // Webhook URL
    string event;                     // イベントタイプ
    string data;                      // データ（JSON）
    string signature;                 // 署名
    datetime timestamp;               // タイムスタンプ
};
```

## 4. 設定ファイルフォーマット

### 4.1 EA設定（JSON形式）
```json
{
    "general": {
        "magicNumber": 20250825,
        "comment": "FX5MinScalping",
        "symbol": "EURUSD",
        "timeframe": "M5",
        "lotSize": 0.01,
        "maxSpread": 2.0
    },
    
    "risk": {
        "maxRiskPerTrade": 2.0,
        "maxDailyLoss": 5.0,
        "maxDrawdown": 20.0,
        "maxConcurrentTrades": 2,
        "defaultStopLoss": 10.0,
        "defaultTakeProfit": 20.0,
        "minRiskRewardRatio": 1.5
    },
    
    "plugins": {
        "patternBreak": {
            "enabled": true,
            "minBuildupBars": 3,
            "maxBuildupBars": 10,
            "breakoutMinPips": 2.0,
            "maxEMADistance": 15.0
        },
        "pullback": {
            "enabled": true,
            "minPullbackDepth": 30.0,
            "maxPullbackDepth": 70.0,
            "requireEMATouch": true
        },
        "combo": {
            "enabled": true,
            "minComboFactors": 2,
            "comboScoreThreshold": 70.0
        }
    },
    
    "trading": {
        "sessions": {
            "london": {
                "enabled": true,
                "start": "07:00",
                "end": "16:00"
            },
            "newyork": {
                "enabled": true,
                "start": "12:00",
                "end": "21:00"
            }
        },
        "filters": {
            "useTimeFilter": true,
            "useSpreadFilter": true,
            "useVolatilityFilter": true,
            "useNewsFilter": false
        }
    },
    
    "notifications": {
        "email": {
            "enabled": false,
            "address": ""
        },
        "push": {
            "enabled": true
        },
        "webhook": {
            "enabled": false,
            "url": ""
        }
    }
}
```

### 4.2 ログフォーマット
```
[TIMESTAMP] [LEVEL] [MODULE] [MESSAGE]

例:
[2025-08-25 14:30:15] [INFO] [PatternBreak] Pattern detected: RANGE at 1.0850-1.0870
[2025-08-25 14:35:22] [SIGNAL] [PatternBreak] BUY signal generated at 1.0872
[2025-08-25 14:35:23] [TRADE] [OrderManager] Position opened: #12345 BUY 0.01 at 1.0872
[2025-08-25 14:45:30] [TRADE] [OrderManager] Position closed: #12345 +18.5 pips
[2025-08-25 14:45:31] [INFO] [RiskManager] Daily P&L: +$18.50 (1.85%)
```

## 5. エラーコード定義

### 5.1 システムエラー
```cpp
#define ERR_SYSTEM_INIT_FAILED        1001  // 初期化失敗
#define ERR_INVALID_PARAMETERS        1002  // 無効なパラメータ
#define ERR_MEMORY_ALLOCATION         1003  // メモリ割り当てエラー
#define ERR_FILE_ACCESS               1004  // ファイルアクセスエラー
#define ERR_NETWORK_CONNECTION        1005  // ネットワーク接続エラー
```

### 5.2 トレードエラー
```cpp
#define ERR_TRADE_CONTEXT_BUSY        2001  // トレードコンテキストビジー
#define ERR_INVALID_STOPS             2002  // 無効なストップレベル
#define ERR_NOT_ENOUGH_MONEY          2003  // 証拠金不足
#define ERR_MAX_POSITIONS_REACHED     2004  // 最大ポジション数到達
#define ERR_SPREAD_TOO_HIGH           2005  // スプレッド過大
```

### 5.3 分析エラー
```cpp
#define ERR_INSUFFICIENT_DATA         3001  // データ不足
#define ERR_PATTERN_NOT_FOUND         3002  // パターン未検出
#define ERR_INVALID_SIGNAL            3003  // 無効なシグナル
#define ERR_CALCULATION_ERROR         3004  // 計算エラー
```

## 6. パフォーマンスメトリクス

### 6.1 測定項目
```cpp
struct PerformanceMetrics {
    // 基本統計
    int totalTrades;                  // 総トレード数
    int winningTrades;                // 勝ちトレード数
    int losingTrades;                 // 負けトレード数
    double winRate;                   // 勝率
    
    // 損益
    double totalProfit;               // 総利益
    double totalLoss;                 // 総損失
    double netProfit;                 // 純利益
    double profitFactor;              // プロフィットファクター
    
    // 平均値
    double averageWin;                // 平均利益
    double averageLoss;               // 平均損失
    double averageRRRatio;            // 平均リスクリワード比
    
    // リスク指標
    double maxDrawdown;               // 最大ドローダウン
    double maxDrawdownPercent;        // 最大DD（%）
    double sharpeRatio;               // シャープレシオ
    double recoveryFactor;            // リカバリーファクター
    
    // 時間分析
    double avgHoldingTime;            // 平均保有時間
    double avgWinTime;                // 平均勝ち時間
    double avgLossTime;               // 平均負け時間
    
    // セットアップ別
    map<string, double> setupWinRate; // セットアップ別勝率
    map<string, double> setupProfit;  // セットアップ別利益
};
```

### 6.2 レポート生成
```cpp
class CPerformanceReporter {
public:
    string GenerateDailyReport(datetime date);
    string GenerateWeeklyReport(datetime weekStart);
    string GenerateMonthlyReport(int year, int month);
    void ExportToCSV(string filename);
    void ExportToHTML(string filename);
    void SendReport(string recipient);
};
```

---
*作成日: 2025-08-25*
*バージョン: 1.0*