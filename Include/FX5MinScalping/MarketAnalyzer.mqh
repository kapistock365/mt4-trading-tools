//+------------------------------------------------------------------+
//|                                              MarketAnalyzer.mqh |
//|                        FX 5分足スキャルピング 市場分析モジュール |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, FX5MinScalping"
#property link      "https://github.com/kapistock365/mt4-trading-tools"
#property strict

#include "DataStructures.mqh"

//+------------------------------------------------------------------+
//| MarketAnalyzer クラス定義                                        |
//+------------------------------------------------------------------+
class CMarketAnalyzer {
private:
    // 設定パラメータ
    int m_timeframe;                 // 分析時間軸
    int m_lookbackPeriod;            // 過去参照期間
    string m_symbol;                 // 通貨ペア
    
    // キャッシュ
    MarketCondition m_currentCondition;
    TechnicalIndicators m_indicators;
    datetime m_lastUpdateTime;
    
    // サポート/レジスタンス
    double m_supportLevels[];
    double m_resistanceLevels[];
    int m_supportCount;
    int m_resistanceCount;
    
    // 内部メソッド
    void CalculateSupportResistance();
    void UpdateTechnicalIndicators();
    void UpdateTrendAnalysis();
    void UpdateVolatilityAnalysis();
    void UpdateSessionInfo();
    double CalculateTrendStrength();
    
public:
    // コンストラクタ/デストラクタ
    CMarketAnalyzer();
    ~CMarketAnalyzer();
    
    // 初期化
    bool Initialize(string symbol = NULL, int timeframe = PERIOD_M5, int lookback = 100);
    
    // 市場状態更新
    void UpdateMarketCondition();
    
    // トレンド分析
    int GetTrendDirection();
    double GetTrendStrength();
    bool IsTrending();
    
    // サポート/レジスタンス
    double GetNearestSupport();
    double GetNearestResistance();
    bool IsNearKeyLevel(double price, double distancePips);
    double GetKeyLevel(int index);
    int GetKeyLevelCount();
    
    // ボラティリティ
    double GetATR(int period);
    double GetCurrentVolatility();
    bool IsVolatilityNormal();
    string GetVolatilityLevel();
    
    // プライスアクション
    bool IsBuildup(int startBar, int endBar);
    bool IsFalseBreak(int bar);
    bool IsTeaseBreak(int bar);
    bool IsPinBar(int bar);
    bool IsInsideBar(int bar);
    
    // 25EMA関連
    double GetEMA(int period, int shift = 0);
    double GetDistanceFromEMA(double price);
    bool IsPriceAboveEMA();
    double GetEMASlope();
    
    // セッション情報
    string GetCurrentSession();
    bool IsOptimalTradingTime();
    bool IsLondonSession();
    bool IsNYSession();
    bool IsAsianSession();
    
    // データアクセス
    MarketCondition GetMarketCondition() { return m_currentCondition; }
    TechnicalIndicators GetIndicators() { return m_indicators; }
    
    // パターン検出
    bool DetectRangePattern(PatternInfo &pattern);
    bool DetectTrianglePattern(PatternInfo &pattern);
    bool DetectChannelPattern(PatternInfo &pattern);
};

//+------------------------------------------------------------------+
//| コンストラクタ                                                   |
//+------------------------------------------------------------------+
CMarketAnalyzer::CMarketAnalyzer() {
    m_timeframe = PERIOD_M5;
    m_lookbackPeriod = 100;
    m_symbol = Symbol();
    m_lastUpdateTime = 0;
    m_supportCount = 0;
    m_resistanceCount = 0;
}

//+------------------------------------------------------------------+
//| デストラクタ                                                     |
//+------------------------------------------------------------------+
CMarketAnalyzer::~CMarketAnalyzer() {
}

//+------------------------------------------------------------------+
//| 初期化                                                           |
//+------------------------------------------------------------------+
bool CMarketAnalyzer::Initialize(string symbol = NULL, int timeframe = PERIOD_M5, int lookback = 100) {
    m_symbol = (symbol == NULL) ? Symbol() : symbol;
    m_timeframe = timeframe;
    m_lookbackPeriod = lookback;
    
    // 配列のサイズ設定
    ArrayResize(m_supportLevels, 10);
    ArrayResize(m_resistanceLevels, 10);
    ArrayResize(m_currentCondition.keyLevels, 10);
    
    // 初回更新
    UpdateMarketCondition();
    
    return true;
}

//+------------------------------------------------------------------+
//| 市場状態更新                                                     |
//+------------------------------------------------------------------+
void CMarketAnalyzer::UpdateMarketCondition() {
    // 更新頻度の制御（1分毎）
    if(TimeCurrent() - m_lastUpdateTime < 60) return;
    
    // 各種分析を更新
    UpdateTechnicalIndicators();
    UpdateTrendAnalysis();
    UpdateVolatilityAnalysis();
    UpdateSessionInfo();
    CalculateSupportResistance();
    
    // スプレッド情報
    double spread = MarketInfo(m_symbol, MODE_SPREAD);
    m_currentCondition.currentSpread = PriceToPips(spread * Point);
    
    // 更新時刻
    m_currentCondition.lastUpdate = TimeCurrent();
    m_lastUpdateTime = TimeCurrent();
}

//+------------------------------------------------------------------+
//| テクニカルインジケーター更新                                     |
//+------------------------------------------------------------------+
void CMarketAnalyzer::UpdateTechnicalIndicators() {
    // 移動平均
    m_indicators.ema25 = iMA(m_symbol, m_timeframe, 25, 0, MODE_EMA, PRICE_CLOSE, 0);
    m_indicators.ema50 = iMA(m_symbol, m_timeframe, 50, 0, MODE_EMA, PRICE_CLOSE, 0);
    m_indicators.ema100 = iMA(m_symbol, m_timeframe, 100, 0, MODE_EMA, PRICE_CLOSE, 0);
    m_indicators.ema200 = iMA(m_symbol, m_timeframe, 200, 0, MODE_EMA, PRICE_CLOSE, 0);
    
    // オシレーター
    m_indicators.rsi14 = iRSI(m_symbol, m_timeframe, 14, PRICE_CLOSE, 0);
    m_indicators.stochK = iStochastic(m_symbol, m_timeframe, 5, 3, 3, MODE_SMA, 0, MODE_MAIN, 0);
    m_indicators.stochD = iStochastic(m_symbol, m_timeframe, 5, 3, 3, MODE_SMA, 0, MODE_SIGNAL, 0);
    
    // MACD
    m_indicators.macdMain = iMACD(m_symbol, m_timeframe, 12, 26, 9, PRICE_CLOSE, MODE_MAIN, 0);
    m_indicators.macdSignal = iMACD(m_symbol, m_timeframe, 12, 26, 9, PRICE_CLOSE, MODE_SIGNAL, 0);
    m_indicators.macdHistogram = m_indicators.macdMain - m_indicators.macdSignal;
    
    // ボラティリティ
    m_indicators.atr14 = iATR(m_symbol, m_timeframe, 14, 0);
    m_indicators.atr20 = iATR(m_symbol, m_timeframe, 20, 0);
    
    // ボリンジャーバンド
    m_indicators.bollingerUpper = iBands(m_symbol, m_timeframe, 20, 2, 0, PRICE_CLOSE, MODE_UPPER, 0);
    m_indicators.bollingerMiddle = iBands(m_symbol, m_timeframe, 20, 2, 0, PRICE_CLOSE, MODE_MAIN, 0);
    m_indicators.bollingerLower = iBands(m_symbol, m_timeframe, 20, 2, 0, PRICE_CLOSE, MODE_LOWER, 0);
    
    // ピボットポイント計算
    double high = iHigh(m_symbol, PERIOD_D1, 1);
    double low = iLow(m_symbol, PERIOD_D1, 1);
    double close = iClose(m_symbol, PERIOD_D1, 1);
    
    m_indicators.pivotPoint = (high + low + close) / 3;
    m_indicators.r1 = 2 * m_indicators.pivotPoint - low;
    m_indicators.r2 = m_indicators.pivotPoint + (high - low);
    m_indicators.r3 = high + 2 * (m_indicators.pivotPoint - low);
    m_indicators.s1 = 2 * m_indicators.pivotPoint - high;
    m_indicators.s2 = m_indicators.pivotPoint - (high - low);
    m_indicators.s3 = low - 2 * (high - m_indicators.pivotPoint);
}

//+------------------------------------------------------------------+
//| トレンド分析更新                                                 |
//+------------------------------------------------------------------+
void CMarketAnalyzer::UpdateTrendAnalysis() {
    double currentPrice = iClose(m_symbol, m_timeframe, 0);
    
    // 25EMA関連
    m_currentCondition.ema25 = m_indicators.ema25;
    m_currentCondition.priceToEmaDistance = PriceToPips(currentPrice - m_indicators.ema25);
    
    // EMA傾き計算（5期間前と比較）
    double ema25_5 = iMA(m_symbol, m_timeframe, 25, 0, MODE_EMA, PRICE_CLOSE, 5);
    m_currentCondition.emaSlope = PriceToPips(m_indicators.ema25 - ema25_5) / 5.0;
    
    // トレンド方向判定
    if(currentPrice > m_indicators.ema25 && m_currentCondition.emaSlope > 0.5) {
        m_currentCondition.trendDirection = 1;  // 上昇トレンド
    } else if(currentPrice < m_indicators.ema25 && m_currentCondition.emaSlope < -0.5) {
        m_currentCondition.trendDirection = -1; // 下降トレンド
    } else {
        m_currentCondition.trendDirection = 0;  // レンジ
    }
    
    // トレンド強度計算
    m_currentCondition.trendStrength = CalculateTrendStrength();
}

//+------------------------------------------------------------------+
//| トレンド強度計算                                                 |
//+------------------------------------------------------------------+
double CMarketAnalyzer::CalculateTrendStrength() {
    double strength = 0;
    double currentPrice = iClose(m_symbol, m_timeframe, 0);
    
    // EMA配列の並び（最大25点）
    if(currentPrice > m_indicators.ema25) strength += 10;
    if(m_indicators.ema25 > m_indicators.ema50) strength += 5;
    if(m_indicators.ema50 > m_indicators.ema100) strength += 5;
    if(m_indicators.ema100 > m_indicators.ema200) strength += 5;
    
    // EMA傾き（最大25点）
    double slopeScore = MathMin(25, MathAbs(m_currentCondition.emaSlope) * 5);
    strength += slopeScore;
    
    // RSI（最大25点）
    if(m_indicators.rsi14 > 50 && m_currentCondition.trendDirection > 0) {
        strength += (m_indicators.rsi14 - 50) / 2;
    } else if(m_indicators.rsi14 < 50 && m_currentCondition.trendDirection < 0) {
        strength += (50 - m_indicators.rsi14) / 2;
    }
    
    // MACD（最大25点）
    if(m_indicators.macdHistogram > 0 && m_currentCondition.trendDirection > 0) {
        strength += 12.5;
    } else if(m_indicators.macdHistogram < 0 && m_currentCondition.trendDirection < 0) {
        strength += 12.5;
    }
    if(m_indicators.macdMain > m_indicators.macdSignal && m_currentCondition.trendDirection > 0) {
        strength += 12.5;
    } else if(m_indicators.macdMain < m_indicators.macdSignal && m_currentCondition.trendDirection < 0) {
        strength += 12.5;
    }
    
    return MathMin(100, strength);
}

//+------------------------------------------------------------------+
//| ボラティリティ分析更新                                           |
//+------------------------------------------------------------------+
void CMarketAnalyzer::UpdateVolatilityAnalysis() {
    // ATR値
    m_currentCondition.atr14 = PriceToPips(m_indicators.atr14);
    
    // 平均レンジ計算（過去20本）
    double totalRange = 0;
    for(int i = 0; i < 20; i++) {
        double high = iHigh(m_symbol, m_timeframe, i);
        double low = iLow(m_symbol, m_timeframe, i);
        totalRange += PriceToPips(high - low);
    }
    m_currentCondition.averageRange = totalRange / 20.0;
    
    // ボラティリティレベル判定
    if(m_currentCondition.atr14 < 5.0) {
        m_currentCondition.volatilityLevel = "low";
    } else if(m_currentCondition.atr14 < 10.0) {
        m_currentCondition.volatilityLevel = "medium";
    } else {
        m_currentCondition.volatilityLevel = "high";
    }
}

//+------------------------------------------------------------------+
//| セッション情報更新                                               |
//+------------------------------------------------------------------+
void CMarketAnalyzer::UpdateSessionInfo() {
    datetime currentTime = TimeCurrent();
    int hour = TimeHour(currentTime);
    int minute = TimeMinute(currentTime);
    int totalMinutes = hour * 60 + minute;
    
    // セッション判定（サーバー時間基準、要調整）
    m_currentCondition.isAsianSession = (hour >= 0 && hour < 8);
    m_currentCondition.isLondonOpen = (hour >= 7 && hour < 16);
    m_currentCondition.isNYOpen = (hour >= 12 && hour < 21);
    
    // 現在のセッション
    if(m_currentCondition.isNYOpen && m_currentCondition.isLondonOpen) {
        m_currentCondition.currentSession = "London-NY Overlap";
    } else if(m_currentCondition.isNYOpen) {
        m_currentCondition.currentSession = "New York";
    } else if(m_currentCondition.isLondonOpen) {
        m_currentCondition.currentSession = "London";
    } else if(m_currentCondition.isAsianSession) {
        m_currentCondition.currentSession = "Asian";
    } else {
        m_currentCondition.currentSession = "Off-hours";
    }
    
    // オープンからの経過時間
    if(m_currentCondition.isLondonOpen) {
        m_currentCondition.minutesSinceOpen = totalMinutes - (7 * 60);
    } else if(m_currentCondition.isNYOpen) {
        m_currentCondition.minutesSinceOpen = totalMinutes - (12 * 60);
    } else {
        m_currentCondition.minutesSinceOpen = 0;
    }
}

//+------------------------------------------------------------------+
//| サポート/レジスタンス計算                                        |
//+------------------------------------------------------------------+
void CMarketAnalyzer::CalculateSupportResistance() {
    m_supportCount = 0;
    m_resistanceCount = 0;
    
    double currentPrice = iClose(m_symbol, m_timeframe, 0);
    
    // スイングハイ/ローを探す
    for(int i = 5; i < m_lookbackPeriod - 5; i++) {
        double high = iHigh(m_symbol, m_timeframe, i);
        double low = iLow(m_symbol, m_timeframe, i);
        
        // スイングハイチェック
        bool isSwingHigh = true;
        for(int j = i - 5; j <= i + 5; j++) {
            if(j != i && iHigh(m_symbol, m_timeframe, j) >= high) {
                isSwingHigh = false;
                break;
            }
        }
        
        if(isSwingHigh) {
            if(high > currentPrice && m_resistanceCount < 10) {
                m_resistanceLevels[m_resistanceCount++] = high;
            } else if(high < currentPrice && m_supportCount < 10) {
                m_supportLevels[m_supportCount++] = high;
            }
        }
        
        // スイングローチェック
        bool isSwingLow = true;
        for(int j = i - 5; j <= i + 5; j++) {
            if(j != i && iLow(m_symbol, m_timeframe, j) <= low) {
                isSwingLow = false;
                break;
            }
        }
        
        if(isSwingLow) {
            if(low < currentPrice && m_supportCount < 10) {
                m_supportLevels[m_supportCount++] = low;
            } else if(low > currentPrice && m_resistanceCount < 10) {
                m_resistanceLevels[m_resistanceCount++] = low;
            }
        }
    }
    
    // ソート
    if(m_supportCount > 0) ArraySort(m_supportLevels, m_supportCount, 0, MODE_DESCEND);
    if(m_resistanceCount > 0) ArraySort(m_resistanceLevels, m_resistanceCount, 0, MODE_ASCEND);
    
    // 最も近いレベルを設定
    m_currentCondition.nearestSupport = (m_supportCount > 0) ? m_supportLevels[0] : 0;
    m_currentCondition.nearestResistance = (m_resistanceCount > 0) ? m_resistanceLevels[0] : 0;
    
    // キーレベル統合
    m_currentCondition.keyLevelCount = 0;
    for(int i = 0; i < m_supportCount && m_currentCondition.keyLevelCount < 10; i++) {
        m_currentCondition.keyLevels[m_currentCondition.keyLevelCount++] = m_supportLevels[i];
    }
    for(int i = 0; i < m_resistanceCount && m_currentCondition.keyLevelCount < 10; i++) {
        m_currentCondition.keyLevels[m_currentCondition.keyLevelCount++] = m_resistanceLevels[i];
    }
}

//+------------------------------------------------------------------+
//| トレンド方向取得                                                 |
//+------------------------------------------------------------------+
int CMarketAnalyzer::GetTrendDirection() {
    UpdateMarketCondition();
    return m_currentCondition.trendDirection;
}

//+------------------------------------------------------------------+
//| トレンド強度取得                                                 |
//+------------------------------------------------------------------+
double CMarketAnalyzer::GetTrendStrength() {
    UpdateMarketCondition();
    return m_currentCondition.trendStrength;
}

//+------------------------------------------------------------------+
//| トレンド判定                                                     |
//+------------------------------------------------------------------+
bool CMarketAnalyzer::IsTrending() {
    UpdateMarketCondition();
    return (m_currentCondition.trendDirection != 0 && m_currentCondition.trendStrength > 30);
}

//+------------------------------------------------------------------+
//| 最も近いサポート取得                                             |
//+------------------------------------------------------------------+
double CMarketAnalyzer::GetNearestSupport() {
    UpdateMarketCondition();
    return m_currentCondition.nearestSupport;
}

//+------------------------------------------------------------------+
//| 最も近いレジスタンス取得                                         |
//+------------------------------------------------------------------+
double CMarketAnalyzer::GetNearestResistance() {
    UpdateMarketCondition();
    return m_currentCondition.nearestResistance;
}

//+------------------------------------------------------------------+
//| キーレベル近辺チェック                                           |
//+------------------------------------------------------------------+
bool CMarketAnalyzer::IsNearKeyLevel(double price, double distancePips) {
    UpdateMarketCondition();
    
    for(int i = 0; i < m_currentCondition.keyLevelCount; i++) {
        double distance = MathAbs(PriceToPips(price - m_currentCondition.keyLevels[i]));
        if(distance <= distancePips) return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| ATR取得                                                          |
//+------------------------------------------------------------------+
double CMarketAnalyzer::GetATR(int period) {
    double atr = iATR(m_symbol, m_timeframe, period, 0);
    return PriceToPips(atr);
}

//+------------------------------------------------------------------+
//| 現在のボラティリティ取得                                         |
//+------------------------------------------------------------------+
double CMarketAnalyzer::GetCurrentVolatility() {
    UpdateMarketCondition();
    return m_currentCondition.atr14;
}

//+------------------------------------------------------------------+
//| ボラティリティ正常判定                                           |
//+------------------------------------------------------------------+
bool CMarketAnalyzer::IsVolatilityNormal() {
    UpdateMarketCondition();
    return (m_currentCondition.atr14 >= 3.0 && m_currentCondition.atr14 <= 15.0);
}

//+------------------------------------------------------------------+
//| ボラティリティレベル取得                                         |
//+------------------------------------------------------------------+
string CMarketAnalyzer::GetVolatilityLevel() {
    UpdateMarketCondition();
    return m_currentCondition.volatilityLevel;
}

//+------------------------------------------------------------------+
//| EMA取得                                                          |
//+------------------------------------------------------------------+
double CMarketAnalyzer::GetEMA(int period, int shift = 0) {
    return iMA(m_symbol, m_timeframe, period, 0, MODE_EMA, PRICE_CLOSE, shift);
}

//+------------------------------------------------------------------+
//| EMAからの距離取得                                                |
//+------------------------------------------------------------------+
double CMarketAnalyzer::GetDistanceFromEMA(double price) {
    UpdateMarketCondition();
    return PriceToPips(price - m_currentCondition.ema25);
}

//+------------------------------------------------------------------+
//| 価格がEMAより上か判定                                            |
//+------------------------------------------------------------------+
bool CMarketAnalyzer::IsPriceAboveEMA() {
    UpdateMarketCondition();
    double currentPrice = iClose(m_symbol, m_timeframe, 0);
    return (currentPrice > m_currentCondition.ema25);
}

//+------------------------------------------------------------------+
//| EMA傾き取得                                                      |
//+------------------------------------------------------------------+
double CMarketAnalyzer::GetEMASlope() {
    UpdateMarketCondition();
    return m_currentCondition.emaSlope;
}

//+------------------------------------------------------------------+
//| 現在のセッション取得                                             |
//+------------------------------------------------------------------+
string CMarketAnalyzer::GetCurrentSession() {
    UpdateMarketCondition();
    return m_currentCondition.currentSession;
}

//+------------------------------------------------------------------+
//| 最適トレード時間判定                                             |
//+------------------------------------------------------------------+
bool CMarketAnalyzer::IsOptimalTradingTime() {
    UpdateMarketCondition();
    return (m_currentCondition.isLondonOpen || m_currentCondition.isNYOpen);
}

//+------------------------------------------------------------------+
//| ロンドンセッション判定                                           |
//+------------------------------------------------------------------+
bool CMarketAnalyzer::IsLondonSession() {
    UpdateMarketCondition();
    return m_currentCondition.isLondonOpen;
}

//+------------------------------------------------------------------+
//| NYセッション判定                                                 |
//+------------------------------------------------------------------+
bool CMarketAnalyzer::IsNYSession() {
    UpdateMarketCondition();
    return m_currentCondition.isNYOpen;
}

//+------------------------------------------------------------------+
//| アジアセッション判定                                             |
//+------------------------------------------------------------------+
bool CMarketAnalyzer::IsAsianSession() {
    UpdateMarketCondition();
    return m_currentCondition.isAsianSession;
}

//+------------------------------------------------------------------+
//| レンジパターン検出                                               |
//+------------------------------------------------------------------+
bool CMarketAnalyzer::DetectRangePattern(PatternInfo &pattern) {
    // 過去N本の高値安値を取得
    double highs[], lows[];
    ArrayResize(highs, 20);
    ArrayResize(lows, 20);
    
    for(int i = 0; i < 20; i++) {
        highs[i] = iHigh(m_symbol, m_timeframe, i);
        lows[i] = iLow(m_symbol, m_timeframe, i);
    }
    
    // 最高値と最安値
    int maxIdx = ArrayMaximum(highs);
    int minIdx = ArrayMinimum(lows);
    double rangeHigh = highs[maxIdx];
    double rangeLow = lows[minIdx];
    double rangeSize = PriceToPips(rangeHigh - rangeLow);
    
    // レンジ判定（5-20pips）
    if(rangeSize >= 5.0 && rangeSize <= 20.0) {
        // 高値と安値のタッチ回数をカウント
        int highTouches = 0, lowTouches = 0;
        for(int i = 0; i < 20; i++) {
            if(MathAbs(highs[i] - rangeHigh) < PipsToPrice(1.0)) highTouches++;
            if(MathAbs(lows[i] - rangeLow) < PipsToPrice(1.0)) lowTouches++;
        }
        
        // 最低2回ずつタッチ
        if(highTouches >= 2 && lowTouches >= 2) {
            pattern.patternType = PATTERN_RANGE;
            pattern.upperBoundary = rangeHigh;
            pattern.lowerBoundary = rangeLow;
            pattern.startBar = 19;
            pattern.endBar = 0;
            pattern.startTime = iTime(m_symbol, m_timeframe, 19);
            pattern.endTime = iTime(m_symbol, m_timeframe, 0);
            pattern.patternHeight = rangeSize;
            pattern.touchCount = highTouches + lowTouches;
            pattern.reliability = MathMin(100, (highTouches + lowTouches) * 10);
            pattern.isActive = true;
            
            return true;
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+