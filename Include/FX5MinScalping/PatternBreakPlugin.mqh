//+------------------------------------------------------------------+
//|                                           PatternBreakPlugin.mqh |
//|                   FX 5分足スキャルピング パターンブレイクプラグイン |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, FX5MinScalping"
#property link      "https://github.com/kapistock365/mt4-trading-tools"
#property strict

#include "../PluginBase.mqh"
#include "../Core/OrderManager.mqh"
#include "../Core/AccountManager.mqh"
#include "DataStructures.mqh"
#include "MarketAnalyzer.mqh"
#include "BuildupDetector.mqh"

//+------------------------------------------------------------------+
//| PatternBreakPlugin クラス定義                                    |
//+------------------------------------------------------------------+
class CPatternBreakPlugin : public CPluginBase {
private:
    // === 設定パラメータ ===
    int     m_minBuildupBars;        // 最小ビルドアップバー数
    int     m_maxBuildupBars;        // 最大ビルドアップバー数
    double  m_buildupRangePips;      // ビルドアップ最大幅
    double  m_breakoutMinPips;       // ブレイク最小幅
    double  m_breakoutMaxPips;       // ブレイク最大幅
    double  m_maxEMADistance;        // EMAからの最大距離
    int     m_confirmationBars;      // ブレイク確認バー数
    double  m_stopLossPips;          // 損切り（pips）
    double  m_takeProfitPips;        // 利確（pips）
    double  m_riskPercent;           // リスク率（%）
    int     m_magicNumber;           // マジックナンバー
    int     m_maxTradesPerDay;       // 1日の最大トレード数
    int     m_cooldownMinutes;       // クールダウン時間（分）
    
    // === 内部状態変数 ===
    PatternInfo m_currentPattern;    // 現在のパターン
    BuildupInfo m_currentBuildup;    // 現在のビルドアップ
    SignalInfo  m_lastSignal;        // 最後のシグナル
    datetime    m_lastBreakTime;     // 最後のブレイク時刻
    datetime    m_lastTradeTime;     // 最後のトレード時刻
    int         m_todayTradeCount;   // 本日のトレード数
    bool        m_patternActive;     // パターンアクティブ
    int         m_lastTicket;        // 最後のチケット番号
    
    // === コンポーネント ===
    CMarketAnalyzer*  m_marketAnalyzer;
    CBuildupDetector* m_buildupDetector;
    COrderManager*    m_orderManager;
    CAccountManager*  m_accountManager;
    
    // === 内部メソッド ===
    bool DetectPattern();
    bool CheckBreakout();
    bool ValidateBreakout(int direction);
    bool ApplyFilters(SignalInfo &signal);
    bool CheckTimeFilter();
    bool CheckSpreadFilter();
    bool CheckVolatilityFilter();
    bool CheckEMAFilter();
    bool CheckNewsFilter();
    void ExecuteTrade(SignalInfo &signal);
    void UpdateDailyStats();
    void ResetDailyCounters();
    double CalculateStopLoss(int direction);
    double CalculateTakeProfit(int direction);
    void DrawSignal(SignalInfo &signal);
    void ManageOpenPositions();
    
public:
    // コンストラクタ/デストラクタ
    CPatternBreakPlugin();
    ~CPatternBreakPlugin();
    
    // === CPluginBase実装 ===
    virtual bool OnInit();
    virtual void OnDeinit();
    virtual void OnTick();
    virtual void OnTimer();
    virtual void OnTrade();
    
    // === パラメータ設定 ===
    void SetParameters(
        int minBuildupBars = 3,
        int maxBuildupBars = 10,
        double buildupRange = 10.0,
        double breakoutMin = 2.0,
        double breakoutMax = 5.0,
        double maxEMADist = 15.0,
        int confirmBars = 2,
        double stopLoss = 10.0,
        double takeProfit = 20.0,
        double riskPercent = 2.0
    );
    
    // === データアクセス ===
    SignalInfo GetLastSignal() { return m_lastSignal; }
    int GetTodayTradeCount() { return m_todayTradeCount; }
    bool IsPatternActive() { return m_patternActive; }
    string GetPatternDescription();
};

//+------------------------------------------------------------------+
//| コンストラクタ                                                   |
//+------------------------------------------------------------------+
CPatternBreakPlugin::CPatternBreakPlugin() : 
    CPluginBase("PatternBreak", "1.0", "FX 5-minute Scalping Pattern Break Plugin") {
    
    // デフォルトパラメータ設定
    m_minBuildupBars = 3;
    m_maxBuildupBars = 10;
    m_buildupRangePips = 10.0;
    m_breakoutMinPips = 2.0;
    m_breakoutMaxPips = 5.0;
    m_maxEMADistance = 15.0;
    m_confirmationBars = 2;
    m_stopLossPips = 10.0;
    m_takeProfitPips = 20.0;
    m_riskPercent = 2.0;
    m_magicNumber = 20250825;
    m_maxTradesPerDay = 5;
    m_cooldownMinutes = 30;
    
    // 状態初期化
    m_patternActive = false;
    m_lastBreakTime = 0;
    m_lastTradeTime = 0;
    m_todayTradeCount = 0;
    m_lastTicket = -1;
    
    // コンポーネント初期化
    m_marketAnalyzer = NULL;
    m_buildupDetector = NULL;
    m_orderManager = NULL;
    m_accountManager = NULL;
}

//+------------------------------------------------------------------+
//| デストラクタ                                                     |
//+------------------------------------------------------------------+
CPatternBreakPlugin::~CPatternBreakPlugin() {
    if(m_marketAnalyzer != NULL) {
        delete m_marketAnalyzer;
        m_marketAnalyzer = NULL;
    }
    if(m_buildupDetector != NULL) {
        delete m_buildupDetector;
        m_buildupDetector = NULL;
    }
    if(m_orderManager != NULL) {
        delete m_orderManager;
        m_orderManager = NULL;
    }
    if(m_accountManager != NULL) {
        delete m_accountManager;
        m_accountManager = NULL;
    }
}

//+------------------------------------------------------------------+
//| 初期化                                                           |
//+------------------------------------------------------------------+
bool CPatternBreakPlugin::OnInit() {
    Print(m_name + " initializing...");
    
    // コンポーネント作成
    m_marketAnalyzer = new CMarketAnalyzer();
    if(!m_marketAnalyzer.Initialize(Symbol(), PERIOD_M5, 100)) {
        Print("Failed to initialize MarketAnalyzer");
        return false;
    }
    
    m_buildupDetector = new CBuildupDetector();
    if(!m_buildupDetector.Initialize(m_minBuildupBars, m_maxBuildupBars, m_buildupRangePips)) {
        Print("Failed to initialize BuildupDetector");
        return false;
    }
    
    m_orderManager = new COrderManager();
    if(!m_orderManager.Initialize(m_magicNumber, 3)) {
        Print("Failed to initialize OrderManager");
        return false;
    }
    
    m_accountManager = new CAccountManager();
    if(!m_accountManager.Initialize(m_riskPercent)) {
        Print("Failed to initialize AccountManager");
        return false;
    }
    
    // タイマー設定（1分毎）
    EventSetTimer(60);
    
    Print(m_name + " initialized successfully");
    return true;
}

//+------------------------------------------------------------------+
//| 終了処理                                                         |
//+------------------------------------------------------------------+
void CPatternBreakPlugin::OnDeinit() {
    EventKillTimer();
    
    // オブジェクト削除
    ObjectsDeleteAll(0, "PB_");
    
    Print(m_name + " deinitialized");
}

//+------------------------------------------------------------------+
//| ティック処理                                                     |
//+------------------------------------------------------------------+
void CPatternBreakPlugin::OnTick() {
    if(m_state != PLUGIN_STATE_ENABLED) return;
    
    // 新しいバーの場合のみ処理（5分足）
    static datetime lastBarTime = 0;
    datetime currentBarTime = iTime(Symbol(), PERIOD_M5, 0);
    if(currentBarTime == lastBarTime) return;
    lastBarTime = currentBarTime;
    
    // 市場状態更新
    m_marketAnalyzer.UpdateMarketCondition();
    
    // 既存ポジション管理
    ManageOpenPositions();
    
    // 日次統計更新
    UpdateDailyStats();
    
    // トレード数制限チェック
    if(m_todayTradeCount >= m_maxTradesPerDay) {
        return;
    }
    
    // クールダウンチェック
    if(TimeCurrent() - m_lastTradeTime < m_cooldownMinutes * 60) {
        return;
    }
    
    // パターン検出
    if(!m_patternActive) {
        DetectPattern();
    }
    
    // ブレイクアウトチェック
    if(m_patternActive) {
        if(CheckBreakout()) {
            // シグナル生成
            if(ApplyFilters(m_lastSignal)) {
                // トレード実行
                ExecuteTrade(m_lastSignal);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| タイマー処理                                                     |
//+------------------------------------------------------------------+
void CPatternBreakPlugin::OnTimer() {
    // 日次リセット（サーバー時間0時）
    static int lastDay = -1;
    int currentDay = TimeDay(TimeCurrent());
    
    if(currentDay != lastDay) {
        ResetDailyCounters();
        lastDay = currentDay;
    }
}

//+------------------------------------------------------------------+
//| トレード処理                                                     |
//+------------------------------------------------------------------+
void CPatternBreakPlugin::OnTrade() {
    // トレード実行後の処理
}

//+------------------------------------------------------------------+
//| パターン検出                                                     |
//+------------------------------------------------------------------+
bool CPatternBreakPlugin::DetectPattern() {
    // レンジパターン検出
    if(m_marketAnalyzer.DetectRangePattern(m_currentPattern)) {
        // ビルドアップ検出
        if(m_buildupDetector.DetectBuildup(0)) {
            m_currentBuildup = m_buildupDetector.GetCurrentBuildup();
            
            // ビルドアップがパターン境界付近にあるか確認
            double distanceToUpper = PriceToPips(m_currentPattern.upperBoundary - m_currentBuildup.centerPrice);
            double distanceToLower = PriceToPips(m_currentBuildup.centerPrice - m_currentPattern.lowerBoundary);
            
            if(distanceToUpper <= 3.0 || distanceToLower <= 3.0) {
                m_patternActive = true;
                
                // パターン描画
                m_buildupDetector.DrawBuildup("PB", m_currentBuildup, clrYellow);
                
                Print("Pattern detected: ", GetPatternDescription());
                return true;
            }
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| ブレイクアウトチェック                                           |
//+------------------------------------------------------------------+
bool CPatternBreakPlugin::CheckBreakout() {
    if(!m_patternActive) return false;
    
    double currentClose = iClose(Symbol(), PERIOD_M5, 0);
    double prevClose = iClose(Symbol(), PERIOD_M5, 1);
    
    // 上方ブレイク
    if(currentClose > m_currentPattern.upperBoundary + PipsToPrice(m_breakoutMinPips)) {
        if(ValidateBreakout(1)) {
            // シグナル生成
            m_lastSignal.signalType = 1;  // 買い
            m_lastSignal.setupName = "Pattern Break UP";
            m_lastSignal.entryPrice = Ask;
            m_lastSignal.stopLoss = CalculateStopLoss(1);
            m_lastSignal.takeProfit = CalculateTakeProfit(1);
            m_lastSignal.signalStrength = m_currentBuildup.quality;
            m_lastSignal.generatedTime = TimeCurrent();
            m_lastSignal.expirationTime = TimeCurrent() + 300;  // 5分有効
            m_lastSignal.isValid = true;
            
            m_lastBreakTime = TimeCurrent();
            m_patternActive = false;  // パターン無効化
            
            return true;
        }
    }
    
    // 下方ブレイク
    if(currentClose < m_currentPattern.lowerBoundary - PipsToPrice(m_breakoutMinPips)) {
        if(ValidateBreakout(-1)) {
            // シグナル生成
            m_lastSignal.signalType = -1;  // 売り
            m_lastSignal.setupName = "Pattern Break DOWN";
            m_lastSignal.entryPrice = Bid;
            m_lastSignal.stopLoss = CalculateStopLoss(-1);
            m_lastSignal.takeProfit = CalculateTakeProfit(-1);
            m_lastSignal.signalStrength = m_currentBuildup.quality;
            m_lastSignal.generatedTime = TimeCurrent();
            m_lastSignal.expirationTime = TimeCurrent() + 300;
            m_lastSignal.isValid = true;
            
            m_lastBreakTime = TimeCurrent();
            m_patternActive = false;
            
            return true;
        }
    }
    
    // パターン無効化チェック（時間経過）
    if(iTime(Symbol(), PERIOD_M5, 0) - m_currentPattern.startTime > 3600) {  // 1時間以上
        m_patternActive = false;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| ブレイクアウト検証                                               |
//+------------------------------------------------------------------+
bool CPatternBreakPlugin::ValidateBreakout(int direction) {
    // 1. ブレイク幅チェック
    double breakSize = 0;
    if(direction > 0) {
        breakSize = PriceToPips(iClose(Symbol(), PERIOD_M5, 0) - m_currentPattern.upperBoundary);
    } else {
        breakSize = PriceToPips(m_currentPattern.lowerBoundary - iClose(Symbol(), PERIOD_M5, 0));
    }
    
    if(breakSize < m_breakoutMinPips || breakSize > m_breakoutMaxPips) {
        return false;
    }
    
    // 2. 確認バーチェック
    if(m_confirmationBars > 1) {
        for(int i = 1; i < m_confirmationBars; i++) {
            if(direction > 0) {
                if(iClose(Symbol(), PERIOD_M5, i) <= m_currentPattern.upperBoundary) {
                    return false;
                }
            } else {
                if(iClose(Symbol(), PERIOD_M5, i) >= m_currentPattern.lowerBoundary) {
                    return false;
                }
            }
        }
    }
    
    // 3. ビルドアップ方向との一致
    if(m_currentBuildup.direction != 0 && m_currentBuildup.direction != direction) {
        return false;  // 方向が逆
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| フィルター適用                                                   |
//+------------------------------------------------------------------+
bool CPatternBreakPlugin::ApplyFilters(SignalInfo &signal) {
    // 時間フィルター
    if(!CheckTimeFilter()) {
        signal.isValid = false;
        signal.additionalInfo = "Time filter failed";
        return false;
    }
    
    // スプレッドフィルター
    if(!CheckSpreadFilter()) {
        signal.isValid = false;
        signal.additionalInfo = "Spread too high";
        return false;
    }
    
    // ボラティリティフィルター
    if(!CheckVolatilityFilter()) {
        signal.isValid = false;
        signal.additionalInfo = "Volatility abnormal";
        return false;
    }
    
    // EMAフィルター
    if(!CheckEMAFilter()) {
        signal.isValid = false;
        signal.additionalInfo = "Too far from EMA";
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| 時間フィルター                                                   |
//+------------------------------------------------------------------+
bool CPatternBreakPlugin::CheckTimeFilter() {
    return m_marketAnalyzer.IsOptimalTradingTime();
}

//+------------------------------------------------------------------+
//| スプレッドフィルター                                             |
//+------------------------------------------------------------------+
bool CPatternBreakPlugin::CheckSpreadFilter() {
    double spread = MarketInfo(Symbol(), MODE_SPREAD);
    double spreadPips = PriceToPips(spread * Point);
    
    return (spreadPips <= 2.0);  // 最大2pips
}

//+------------------------------------------------------------------+
//| ボラティリティフィルター                                         |
//+------------------------------------------------------------------+
bool CPatternBreakPlugin::CheckVolatilityFilter() {
    return m_marketAnalyzer.IsVolatilityNormal();
}

//+------------------------------------------------------------------+
//| EMAフィルター                                                    |
//+------------------------------------------------------------------+
bool CPatternBreakPlugin::CheckEMAFilter() {
    double currentPrice = (m_lastSignal.signalType > 0) ? Ask : Bid;
    double distance = MathAbs(m_marketAnalyzer.GetDistanceFromEMA(currentPrice));
    
    return (distance <= m_maxEMADistance);
}

//+------------------------------------------------------------------+
//| トレード実行                                                     |
//+------------------------------------------------------------------+
void CPatternBreakPlugin::ExecuteTrade(SignalInfo &signal) {
    // ロット計算
    double lots = m_accountManager.CalculateLotSize(m_stopLossPips);
    
    // 注文実行
    int ticket = -1;
    if(signal.signalType > 0) {
        // 買い注文
        ticket = m_orderManager.OpenBuyOrder(
            lots,
            signal.stopLoss,
            signal.takeProfit,
            signal.setupName,
            m_magicNumber
        );
    } else if(signal.signalType < 0) {
        // 売り注文
        ticket = m_orderManager.OpenSellOrder(
            lots,
            signal.stopLoss,
            signal.takeProfit,
            signal.setupName,
            m_magicNumber
        );
    }
    
    if(ticket > 0) {
        m_lastTicket = ticket;
        m_lastTradeTime = TimeCurrent();
        m_todayTradeCount++;
        
        // シグナル描画
        DrawSignal(signal);
        
        Print("Trade executed: Ticket=", ticket, " Setup=", signal.setupName, 
              " Lots=", lots, " SL=", signal.stopLoss, " TP=", signal.takeProfit);
    } else {
        Print("Trade execution failed: ", GetLastError());
    }
}

//+------------------------------------------------------------------+
//| 損切り計算                                                       |
//+------------------------------------------------------------------+
double CPatternBreakPlugin::CalculateStopLoss(int direction) {
    double sl = 0;
    
    if(direction > 0) {
        // 買いの場合：ビルドアップ下限の2pips下
        sl = m_currentBuildup.rangeLow - PipsToPrice(2.0);
        
        // 最大損切り制限
        if(Ask - sl > PipsToPrice(m_stopLossPips)) {
            sl = Ask - PipsToPrice(m_stopLossPips);
        }
    } else {
        // 売りの場合：ビルドアップ上限の2pips上
        sl = m_currentBuildup.rangeHigh + PipsToPrice(2.0);
        
        // 最大損切り制限
        if(sl - Bid > PipsToPrice(m_stopLossPips)) {
            sl = Bid + PipsToPrice(m_stopLossPips);
        }
    }
    
    return NormalizeDouble(sl, Digits);
}

//+------------------------------------------------------------------+
//| 利確計算                                                         |
//+------------------------------------------------------------------+
double CPatternBreakPlugin::CalculateTakeProfit(int direction) {
    double tp = 0;
    
    if(direction > 0) {
        tp = Ask + PipsToPrice(m_takeProfitPips);
    } else {
        tp = Bid - PipsToPrice(m_takeProfitPips);
    }
    
    return NormalizeDouble(tp, Digits);
}

//+------------------------------------------------------------------+
//| オープンポジション管理                                           |
//+------------------------------------------------------------------+
void CPatternBreakPlugin::ManageOpenPositions() {
    // トレーリングストップやブレークイーブンの管理
    m_orderManager.ManageTrailingStop(10.0, 5.0);  // 10pips利益でトレール開始、5pips幅
    m_orderManager.ManageBreakEven(5.0, 1.0);      // 5pips利益でブレークイーブン
}

//+------------------------------------------------------------------+
//| 日次統計更新                                                     |
//+------------------------------------------------------------------+
void CPatternBreakPlugin::UpdateDailyStats() {
    // 本日のトレード数をカウント
    int count = 0;
    datetime todayStart = iTime(Symbol(), PERIOD_D1, 0);
    
    for(int i = OrdersHistoryTotal() - 1; i >= 0; i--) {
        if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) {
            if(OrderMagicNumber() == m_magicNumber && OrderOpenTime() >= todayStart) {
                count++;
            }
        }
    }
    
    m_todayTradeCount = count;
}

//+------------------------------------------------------------------+
//| 日次カウンターリセット                                           |
//+------------------------------------------------------------------+
void CPatternBreakPlugin::ResetDailyCounters() {
    m_todayTradeCount = 0;
    Print(m_name + " daily counters reset");
}

//+------------------------------------------------------------------+
//| シグナル描画                                                     |
//+------------------------------------------------------------------+
void CPatternBreakPlugin::DrawSignal(SignalInfo &signal) {
    string prefix = "PB_signal_" + TimeToString(signal.generatedTime);
    
    // エントリー矢印
    if(signal.signalType > 0) {
        ObjectCreate(0, prefix + "_arrow", OBJ_ARROW_UP, 0, signal.generatedTime, signal.entryPrice);
        ObjectSetInteger(0, prefix + "_arrow", OBJPROP_COLOR, clrLime);
    } else {
        ObjectCreate(0, prefix + "_arrow", OBJ_ARROW_DOWN, 0, signal.generatedTime, signal.entryPrice);
        ObjectSetInteger(0, prefix + "_arrow", OBJPROP_COLOR, clrRed);
    }
    
    ObjectSetInteger(0, prefix + "_arrow", OBJPROP_WIDTH, 2);
    
    // テキストラベル
    ObjectCreate(0, prefix + "_label", OBJ_TEXT, 0, signal.generatedTime, signal.entryPrice);
    ObjectSetString(0, prefix + "_label", OBJPROP_TEXT, signal.setupName);
    ObjectSetInteger(0, prefix + "_label", OBJPROP_COLOR, clrWhite);
}

//+------------------------------------------------------------------+
//| パラメータ設定                                                   |
//+------------------------------------------------------------------+
void CPatternBreakPlugin::SetParameters(
    int minBuildupBars = 3,
    int maxBuildupBars = 10,
    double buildupRange = 10.0,
    double breakoutMin = 2.0,
    double breakoutMax = 5.0,
    double maxEMADist = 15.0,
    int confirmBars = 2,
    double stopLoss = 10.0,
    double takeProfit = 20.0,
    double riskPercent = 2.0
) {
    m_minBuildupBars = minBuildupBars;
    m_maxBuildupBars = maxBuildupBars;
    m_buildupRangePips = buildupRange;
    m_breakoutMinPips = breakoutMin;
    m_breakoutMaxPips = breakoutMax;
    m_maxEMADistance = maxEMADist;
    m_confirmationBars = confirmBars;
    m_stopLossPips = stopLoss;
    m_takeProfitPips = takeProfit;
    m_riskPercent = riskPercent;
}

//+------------------------------------------------------------------+
//| パターン説明取得                                                 |
//+------------------------------------------------------------------+
string CPatternBreakPlugin::GetPatternDescription() {
    if(!m_patternActive) return "No active pattern";
    
    string desc = "Pattern: ";
    
    switch(m_currentPattern.patternType) {
        case PATTERN_RANGE:
            desc += "Range";
            break;
        case PATTERN_TRIANGLE_ASC:
            desc += "Ascending Triangle";
            break;
        case PATTERN_TRIANGLE_DESC:
            desc += "Descending Triangle";
            break;
        default:
            desc += "Unknown";
    }
    
    desc += StringFormat(" | Buildup: %d bars, %.1f pips | Quality: %.0f%%",
        m_currentBuildup.barCount,
        m_currentBuildup.rangeSize,
        m_currentBuildup.quality
    );
    
    return desc;
}

//+------------------------------------------------------------------+