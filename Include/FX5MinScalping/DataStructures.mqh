//+------------------------------------------------------------------+
//|                                              DataStructures.mqh |
//|                        FX 5分足スキャルピング データ構造定義     |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, FX5MinScalping"
#property link      "https://github.com/kapistock365/mt4-trading-tools"
#property strict

//+------------------------------------------------------------------+
//| 基本データ構造                                                   |
//+------------------------------------------------------------------+

// 価格データ
struct PriceData {
    double open;                    // 始値
    double high;                    // 高値
    double low;                     // 安値
    double close;                   // 終値
    datetime time;                  // 時刻
    long volume;                    // 出来高
    int spread;                     // スプレッド（ポイント）
};

// バー情報
struct BarInfo {
    PriceData price;                // 価格データ
    double body;                    // 実体サイズ
    double upperWick;               // 上ヒゲ
    double lowerWick;               // 下ヒゲ
    double range;                   // 高値-安値
    int type;                       // 1:陽線, -1:陰線, 0:同時線
    bool isDoji;                    // 同時線フラグ
    bool isPinBar;                  // ピンバーフラグ
    bool isInsideBar;               // インサイドバーフラグ
};

// パターンタイプ
enum ENUM_PATTERN_TYPE {
    PATTERN_NONE = 0,
    PATTERN_RANGE,                  // レンジ
    PATTERN_TRIANGLE_ASC,           // 上昇三角形
    PATTERN_TRIANGLE_DESC,          // 下降三角形
    PATTERN_TRIANGLE_SYM,           // 対称三角形
    PATTERN_FLAG_BULL,              // 上昇フラグ
    PATTERN_FLAG_BEAR,              // 下降フラグ
    PATTERN_WEDGE_RISING,           // 上昇ウェッジ
    PATTERN_WEDGE_FALLING,          // 下降ウェッジ
    PATTERN_CHANNEL_UP,             // 上昇チャネル
    PATTERN_CHANNEL_DOWN,           // 下降チャネル
    PATTERN_HEAD_SHOULDERS,         // ヘッドアンドショルダー
    PATTERN_DOUBLE_TOP,             // ダブルトップ
    PATTERN_DOUBLE_BOTTOM           // ダブルボトム
};

// パターン情報
struct PatternInfo {
    ENUM_PATTERN_TYPE patternType;  // パターンタイプ
    double upperBoundary;            // 上限価格
    double lowerBoundary;            // 下限価格
    int startBar;                    // 開始バー
    int endBar;                      // 終了バー
    datetime startTime;              // 開始時刻
    datetime endTime;                // 終了時刻
    double patternHeight;            // パターン高さ
    int touchCount;                  // タッチ回数
    double reliability;              // 信頼度（0-100）
    bool isActive;                   // アクティブフラグ
};

// ビルドアップ情報
struct BuildupInfo {
    int startBar;                    // 開始バー
    int endBar;                      // 終了バー
    int barCount;                    // バー数
    double rangeHigh;                // レンジ上限
    double rangeLow;                 // レンジ下限
    double rangeSize;                // レンジサイズ（pips）
    double centerPrice;              // 中心価格
    double compression;              // 圧縮度（0-1）
    double dojiRatio;                // 同時線割合
    double avgBarSize;               // 平均バーサイズ
    int direction;                   // 予想方向（1:上, -1:下, 0:不明）
    double quality;                  // 品質スコア（0-100）
    bool isValid;                    // 有効フラグ
};

//+------------------------------------------------------------------+
//| トレード関連データ構造                                           |
//+------------------------------------------------------------------+

// シグナル情報
struct SignalInfo {
    int signalType;                  // 1:買い, -1:売り, 0:なし
    string setupName;                // セットアップ名
    double entryPrice;               // エントリー推奨価格
    double stopLoss;                 // 推奨損切り
    double takeProfit;               // 推奨利確
    double signalStrength;           // シグナル強度（0-100）
    string reason;                   // シグナル理由
    datetime generatedTime;          // 生成時刻
    datetime expirationTime;         // 有効期限
    bool isValid;                    // 有効フラグ
    string additionalInfo;           // 追加情報
};

// トレード要求
struct TradeRequest {
    int operation;                   // 操作タイプ
    double lots;                     // ロット数
    double price;                    // 価格
    double stopLoss;                 // 損切り
    double takeProfit;               // 利確
    int slippage;                    // スリッページ
    string comment;                  // コメント
    int magicNumber;                 // マジックナンバー
    datetime expiration;             // 有効期限
    color arrowColor;                // 矢印色
};

// トレード結果
struct TradeResult {
    bool success;                    // 成功フラグ
    int ticket;                      // チケット番号
    double executedPrice;            // 約定価格
    double executedLots;             // 約定ロット
    int errorCode;                   // エラーコード
    string errorMessage;             // エラーメッセージ
    int retryCount;                  // リトライ回数
    datetime timestamp;              // タイムスタンプ
};

//+------------------------------------------------------------------+
//| 市場分析データ構造                                               |
//+------------------------------------------------------------------+

// 市場状態
struct MarketCondition {
    // トレンド
    int trendDirection;              // -1:下降, 0:レンジ, 1:上昇
    double trendStrength;            // トレンド強度（0-100）
    double ema25;                    // 25EMA値
    double emaSlope;                 // EMA傾き
    double priceToEmaDistance;       // 価格とEMAの距離（pips）
    
    // ボラティリティ
    double atr14;                    // ATR(14)
    string volatilityLevel;          // low/medium/high
    double averageRange;             // 平均レンジ
    
    // サポート/レジスタンス
    double nearestSupport;           // 直近サポート
    double nearestResistance;        // 直近レジスタンス
    double keyLevels[10];            // キーレベル配列
    int keyLevelCount;               // キーレベル数
    
    // 時間帯
    string currentSession;           // 現在のセッション
    bool isLondonOpen;               // ロンドンオープン
    bool isNYOpen;                   // NYオープン
    bool isAsianSession;             // アジアセッション
    int minutesSinceOpen;            // オープンからの経過分
    
    // その他
    double currentSpread;            // 現在のスプレッド（pips）
    double averageSpread;            // 平均スプレッド（pips）
    bool isNewsTime;                 // ニュース時間帯
    datetime lastUpdate;             // 最終更新時刻
};

// テクニカルインジケーター
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

//+------------------------------------------------------------------+
//| リスク管理データ構造                                             |
//+------------------------------------------------------------------+

// リスクパラメータ
struct RiskParameters {
    double maxRiskPerTrade;          // 1トレード最大リスク（%）
    double maxDailyLoss;             // 日次最大損失（%）
    double maxDrawdown;              // 最大ドローダウン（%）
    int maxConcurrentTrades;         // 最大同時ポジション数
    double defaultStopLossPips;      // デフォルト損切り（pips）
    double defaultTakeProfitPips;    // デフォルト利確（pips）
    double minRiskRewardRatio;       // 最小リスクリワード比
    bool useTrailingStop;            // トレーリングストップ使用
    double trailingStartPips;        // トレーリング開始（pips）
    double trailingStepPips;         // トレーリングステップ（pips）
    bool useBreakEven;               // ブレークイーブン使用
    double breakEvenTriggerPips;     // ブレークイーブントリガー（pips）
    bool usePartialClose;            // 部分決済使用
    double partialClosePercent;      // 部分決済割合（%）
    double partialCloseTriggerPips;  // 部分決済トリガー（pips）
};

// リスク状態
struct RiskStatus {
    double currentDailyLoss;         // 現在の日次損失
    double currentDrawdown;          // 現在のドローダウン
    int currentOpenTrades;           // 現在のオープントレード数
    double totalExposure;            // 総エクスポージャー
    bool canTrade;                   // トレード可能フラグ
    string restrictionReason;        // 制限理由
    datetime lastLossTime;           // 最後の損失時刻
    int consecutiveLosses;           // 連続損失数
};

//+------------------------------------------------------------------+
//| ユーティリティ関数                                               |
//+------------------------------------------------------------------+

// pips変換関数（ブローカーの桁数に対応）
double PipsToPrice(double pips) {
    double multiplier = (Digits == 3 || Digits == 5) ? 10.0 : 1.0;
    return pips * Point * multiplier;
}

double PriceToPips(double price) {
    double multiplier = (Digits == 3 || Digits == 5) ? 10.0 : 1.0;
    return price / (Point * multiplier);
}

// バー情報を取得
void GetBarInfo(int shift, BarInfo &bar) {
    bar.price.open = iOpen(NULL, 0, shift);
    bar.price.high = iHigh(NULL, 0, shift);
    bar.price.low = iLow(NULL, 0, shift);
    bar.price.close = iClose(NULL, 0, shift);
    bar.price.time = iTime(NULL, 0, shift);
    bar.price.volume = iVolume(NULL, 0, shift);
    bar.price.spread = (int)MarketInfo(Symbol(), MODE_SPREAD);
    
    bar.body = MathAbs(bar.price.close - bar.price.open);
    bar.range = bar.price.high - bar.price.low;
    
    if(bar.price.close > bar.price.open) {
        bar.type = 1;  // 陽線
        bar.upperWick = bar.price.high - bar.price.close;
        bar.lowerWick = bar.price.open - bar.price.low;
    } else if(bar.price.close < bar.price.open) {
        bar.type = -1; // 陰線
        bar.upperWick = bar.price.high - bar.price.open;
        bar.lowerWick = bar.price.close - bar.price.low;
    } else {
        bar.type = 0;  // 同時線
        bar.upperWick = bar.price.high - bar.price.close;
        bar.lowerWick = bar.price.close - bar.price.low;
    }
    
    // 同時線判定（実体が全体の10%以下）
    bar.isDoji = (bar.range > 0 && bar.body / bar.range <= 0.1);
    
    // ピンバー判定（長い下ヒゲまたは上ヒゲ）
    bar.isPinBar = false;
    if(bar.range > 0) {
        if(bar.upperWick / bar.range > 0.6 || bar.lowerWick / bar.range > 0.6) {
            bar.isPinBar = true;
        }
    }
    
    // インサイドバー判定（前のバーの範囲内）
    bar.isInsideBar = false;
    if(shift < Bars - 1) {
        double prevHigh = iHigh(NULL, 0, shift + 1);
        double prevLow = iLow(NULL, 0, shift + 1);
        if(bar.price.high <= prevHigh && bar.price.low >= prevLow) {
            bar.isInsideBar = true;
        }
    }
}

// 切りの良い数字かチェック
bool IsRoundNumber(double price) {
    double pip = Point * ((Digits == 3 || Digits == 5) ? 10.0 : 1.0);
    double rounded = MathRound(price / (pip * 10)) * (pip * 10);
    return MathAbs(price - rounded) < pip;
}

// 半切りの良い数字かチェック（50レベル）
bool IsHalfRoundNumber(double price) {
    double pip = Point * ((Digits == 3 || Digits == 5) ? 10.0 : 1.0);
    double rounded50 = MathRound(price / (pip * 5)) * (pip * 5);
    return MathAbs(price - rounded50) < pip && !IsRoundNumber(price);
}

//+------------------------------------------------------------------+