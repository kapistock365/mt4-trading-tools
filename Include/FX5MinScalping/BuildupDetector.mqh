//+------------------------------------------------------------------+
//|                                             BuildupDetector.mqh |
//|                        FX 5分足スキャルピング ビルドアップ検出   |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, FX5MinScalping"
#property link      "https://github.com/kapistock365/mt4-trading-tools"
#property strict

#include "DataStructures.mqh"

//+------------------------------------------------------------------+
//| BuildupDetector クラス定義                                       |
//+------------------------------------------------------------------+
class CBuildupDetector {
private:
    // 設定パラメータ
    int m_minBars;                   // 最小ビルドアップバー数
    int m_maxBars;                   // 最大ビルドアップバー数
    double m_maxRangePips;           // 最大レンジ幅（pips）
    double m_compressionThreshold;   // 圧縮閾値
    string m_symbol;                 // 通貨ペア
    int m_timeframe;                 // 時間軸
    
    // 内部データ
    BuildupInfo m_currentBuildup;    // 現在のビルドアップ
    BuildupInfo m_lastValidBuildup;  // 最後の有効なビルドアップ
    datetime m_lastCheckTime;        // 最後のチェック時刻
    
    // 内部メソッド
    double CalculateCompression(int startBar, int endBar);
    double CalculateDojiRatio(int startBar, int endBar);
    double CalculateAverageBarSize(int startBar, int endBar);
    int DetermineDirection(int startBar, int endBar);
    double EvaluateQuality(BuildupInfo &buildup);
    bool IsBarCompressed(int bar);
    bool CheckSequentialCompression(int startBar, int count);
    
public:
    // コンストラクタ/デストラクタ
    CBuildupDetector();
    ~CBuildupDetector();
    
    // 初期化
    bool Initialize(int minBars = 3, int maxBars = 10, double maxRange = 10.0);
    
    // ビルドアップ検出
    bool DetectBuildup(int startBar = 0);
    bool ScanForBuildup(BuildupInfo &buildup);
    bool ValidateBuildup(BuildupInfo &buildup);
    
    // ビルドアップ分析
    double GetBuildupQuality();
    int GetBuildupDirection();
    bool IsBuildupActive();
    bool IsBuildupComplete();
    
    // パターン別ビルドアップ検出
    bool DetectRangeBuildup(int startBar, BuildupInfo &buildup);
    bool DetectTriangleBuildup(int startBar, BuildupInfo &buildup);
    bool DetectFlagBuildup(int startBar, BuildupInfo &buildup);
    
    // 特性分析
    bool IsCompression();
    bool IsExpansion();
    double GetCompressionRatio();
    double GetDojiPercentage();
    
    // データアクセス
    BuildupInfo GetCurrentBuildup() { return m_currentBuildup; }
    BuildupInfo GetLastValidBuildup() { return m_lastValidBuildup; }
    
    // ユーティリティ
    void Reset();
    string GetBuildupDescription();
    void DrawBuildup(string prefix, BuildupInfo &buildup, color clr);
};

//+------------------------------------------------------------------+
//| コンストラクタ                                                   |
//+------------------------------------------------------------------+
CBuildupDetector::CBuildupDetector() {
    m_minBars = 3;
    m_maxBars = 10;
    m_maxRangePips = 10.0;
    m_compressionThreshold = 0.7;
    m_symbol = Symbol();
    m_timeframe = Period();
    m_lastCheckTime = 0;
    
    Reset();
}

//+------------------------------------------------------------------+
//| デストラクタ                                                     |
//+------------------------------------------------------------------+
CBuildupDetector::~CBuildupDetector() {
}

//+------------------------------------------------------------------+
//| 初期化                                                           |
//+------------------------------------------------------------------+
bool CBuildupDetector::Initialize(int minBars = 3, int maxBars = 10, double maxRange = 10.0) {
    m_minBars = minBars;
    m_maxBars = maxBars;
    m_maxRangePips = maxRange;
    m_symbol = Symbol();
    m_timeframe = Period();
    
    Reset();
    
    return true;
}

//+------------------------------------------------------------------+
//| リセット                                                         |
//+------------------------------------------------------------------+
void CBuildupDetector::Reset() {
    m_currentBuildup.startBar = -1;
    m_currentBuildup.endBar = -1;
    m_currentBuildup.barCount = 0;
    m_currentBuildup.rangeHigh = 0;
    m_currentBuildup.rangeLow = 0;
    m_currentBuildup.rangeSize = 0;
    m_currentBuildup.centerPrice = 0;
    m_currentBuildup.compression = 0;
    m_currentBuildup.dojiRatio = 0;
    m_currentBuildup.avgBarSize = 0;
    m_currentBuildup.direction = 0;
    m_currentBuildup.quality = 0;
    m_currentBuildup.isValid = false;
}

//+------------------------------------------------------------------+
//| ビルドアップ検出メイン                                           |
//+------------------------------------------------------------------+
bool CBuildupDetector::DetectBuildup(int startBar = 0) {
    // 新しいバーの場合のみチェック
    if(iTime(m_symbol, m_timeframe, 0) == m_lastCheckTime) {
        return m_currentBuildup.isValid;
    }
    m_lastCheckTime = iTime(m_symbol, m_timeframe, 0);
    
    // 既存のビルドアップをリセット
    Reset();
    
    // 各バー数でビルドアップをチェック
    for(int bars = m_minBars; bars <= m_maxBars; bars++) {
        BuildupInfo tempBuildup;
        
        // ビルドアップ候補を作成
        tempBuildup.startBar = startBar + bars - 1;
        tempBuildup.endBar = startBar;
        tempBuildup.barCount = bars;
        
        // レンジ計算
        double highestHigh = 0;
        double lowestLow = 999999;
        
        for(int i = tempBuildup.endBar; i <= tempBuildup.startBar; i++) {
            double high = iHigh(m_symbol, m_timeframe, i);
            double low = iLow(m_symbol, m_timeframe, i);
            
            if(high > highestHigh) highestHigh = high;
            if(low < lowestLow) lowestLow = low;
        }
        
        tempBuildup.rangeHigh = highestHigh;
        tempBuildup.rangeLow = lowestLow;
        tempBuildup.rangeSize = PriceToPips(highestHigh - lowestLow);
        tempBuildup.centerPrice = (highestHigh + lowestLow) / 2;
        
        // レンジサイズチェック
        if(tempBuildup.rangeSize > m_maxRangePips) continue;
        
        // 各種指標計算
        tempBuildup.compression = CalculateCompression(tempBuildup.startBar, tempBuildup.endBar);
        tempBuildup.dojiRatio = CalculateDojiRatio(tempBuildup.startBar, tempBuildup.endBar);
        tempBuildup.avgBarSize = CalculateAverageBarSize(tempBuildup.startBar, tempBuildup.endBar);
        tempBuildup.direction = DetermineDirection(tempBuildup.startBar, tempBuildup.endBar);
        
        // 品質評価
        tempBuildup.quality = EvaluateQuality(tempBuildup);
        
        // 検証
        if(ValidateBuildup(tempBuildup)) {
            // より良いビルドアップが見つかった場合は更新
            if(tempBuildup.quality > m_currentBuildup.quality) {
                m_currentBuildup = tempBuildup;
                m_currentBuildup.isValid = true;
            }
        }
    }
    
    // 有効なビルドアップが見つかった場合は保存
    if(m_currentBuildup.isValid) {
        m_lastValidBuildup = m_currentBuildup;
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| ビルドアップ検証                                                 |
//+------------------------------------------------------------------+
bool CBuildupDetector::ValidateBuildup(BuildupInfo &buildup) {
    // 基本チェック
    if(buildup.barCount < m_minBars || buildup.barCount > m_maxBars) return false;
    if(buildup.rangeSize > m_maxRangePips) return false;
    if(buildup.rangeSize < 2.0) return false;  // 最小2pips
    
    // 圧縮度チェック
    if(buildup.compression < 0.5) return false;  // 最低50%の圧縮
    
    // 品質チェック
    if(buildup.quality < 60) return false;  // 最低60点
    
    return true;
}

//+------------------------------------------------------------------+
//| 圧縮度計算                                                       |
//+------------------------------------------------------------------+
double CBuildupDetector::CalculateCompression(int startBar, int endBar) {
    if(startBar < endBar) return 0;
    
    int totalBars = startBar - endBar + 1;
    int compressedBars = 0;
    
    // 各バーが圧縮されているかチェック
    for(int i = endBar; i <= startBar; i++) {
        if(IsBarCompressed(i)) compressedBars++;
    }
    
    // 連続圧縮をチェック
    double continuityBonus = 0;
    if(CheckSequentialCompression(endBar, totalBars)) {
        continuityBonus = 0.2;  // 20%ボーナス
    }
    
    double ratio = (double)compressedBars / totalBars + continuityBonus;
    return MathMin(1.0, ratio);
}

//+------------------------------------------------------------------+
//| バーが圧縮されているかチェック                                   |
//+------------------------------------------------------------------+
bool CBuildupDetector::IsBarCompressed(int bar) {
    double range = iHigh(m_symbol, m_timeframe, bar) - iLow(m_symbol, m_timeframe, bar);
    double avgRange = 0;
    
    // 過去10本の平均レンジ
    for(int i = bar + 1; i <= bar + 10 && i < Bars; i++) {
        avgRange += (iHigh(m_symbol, m_timeframe, i) - iLow(m_symbol, m_timeframe, i));
    }
    avgRange /= 10;
    
    // 平均の70%以下なら圧縮
    return (range <= avgRange * 0.7);
}

//+------------------------------------------------------------------+
//| 連続圧縮チェック                                                 |
//+------------------------------------------------------------------+
bool CBuildupDetector::CheckSequentialCompression(int startBar, int count) {
    int sequential = 0;
    
    for(int i = startBar; i < startBar + count; i++) {
        if(IsBarCompressed(i)) {
            sequential++;
            if(sequential >= 3) return true;  // 3本連続で圧縮
        } else {
            sequential = 0;
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| 同時線割合計算                                                   |
//+------------------------------------------------------------------+
double CBuildupDetector::CalculateDojiRatio(int startBar, int endBar) {
    if(startBar < endBar) return 0;
    
    int totalBars = startBar - endBar + 1;
    int dojiBars = 0;
    
    for(int i = endBar; i <= startBar; i++) {
        BarInfo bar;
        GetBarInfo(i, bar);
        
        if(bar.isDoji) dojiBars++;
    }
    
    return (double)dojiBars / totalBars;
}

//+------------------------------------------------------------------+
//| 平均バーサイズ計算                                               |
//+------------------------------------------------------------------+
double CBuildupDetector::CalculateAverageBarSize(int startBar, int endBar) {
    if(startBar < endBar) return 0;
    
    double totalSize = 0;
    int count = startBar - endBar + 1;
    
    for(int i = endBar; i <= startBar; i++) {
        double range = iHigh(m_symbol, m_timeframe, i) - iLow(m_symbol, m_timeframe, i);
        totalSize += PriceToPips(range);
    }
    
    return totalSize / count;
}

//+------------------------------------------------------------------+
//| 方向判定                                                         |
//+------------------------------------------------------------------+
int CBuildupDetector::DetermineDirection(int startBar, int endBar) {
    // ビルドアップの位置と形状から方向を推測
    
    // 1. 全体的な傾き
    double startMid = (iHigh(m_symbol, m_timeframe, startBar) + iLow(m_symbol, m_timeframe, startBar)) / 2;
    double endMid = (iHigh(m_symbol, m_timeframe, endBar) + iLow(m_symbol, m_timeframe, endBar)) / 2;
    double slope = PriceToPips(endMid - startMid);
    
    // 2. 高値と安値の更新パターン
    int higherHighs = 0, lowerLows = 0;
    for(int i = endBar + 1; i <= startBar; i++) {
        if(iHigh(m_symbol, m_timeframe, i - 1) > iHigh(m_symbol, m_timeframe, i)) higherHighs++;
        if(iLow(m_symbol, m_timeframe, i - 1) < iLow(m_symbol, m_timeframe, i)) lowerLows++;
    }
    
    // 3. 終値の位置
    double lastClose = iClose(m_symbol, m_timeframe, endBar);
    double rangePosition = (lastClose - iLow(m_symbol, m_timeframe, endBar)) / 
                          (iHigh(m_symbol, m_timeframe, endBar) - iLow(m_symbol, m_timeframe, endBar));
    
    // 総合判定
    int direction = 0;
    
    if(slope > 1.0 && higherHighs > lowerLows && rangePosition > 0.6) {
        direction = 1;  // 上昇
    } else if(slope < -1.0 && lowerLows > higherHighs && rangePosition < 0.4) {
        direction = -1; // 下降
    }
    
    return direction;
}

//+------------------------------------------------------------------+
//| 品質評価                                                         |
//+------------------------------------------------------------------+
double CBuildupDetector::EvaluateQuality(BuildupInfo &buildup) {
    double quality = 0;
    
    // 1. バー数評価（理想: 5-7本）- 30点
    if(buildup.barCount >= 5 && buildup.barCount <= 7) {
        quality += 30;
    } else if(buildup.barCount >= 3 && buildup.barCount <= 10) {
        quality += 20;
    } else {
        quality += 10;
    }
    
    // 2. 圧縮度評価 - 30点
    quality += buildup.compression * 30;
    
    // 3. レンジサイズ評価（理想: 5-8pips）- 20点
    if(buildup.rangeSize >= 5.0 && buildup.rangeSize <= 8.0) {
        quality += 20;
    } else if(buildup.rangeSize >= 3.0 && buildup.rangeSize <= 10.0) {
        quality += 15;
    } else {
        quality += 5;
    }
    
    // 4. 同時線割合 - 10点
    quality += buildup.dojiRatio * 10;
    
    // 5. 方向性明確さ - 10点
    if(buildup.direction != 0) {
        quality += 10;
    }
    
    return MathMin(100, quality);
}

//+------------------------------------------------------------------+
//| ビルドアップ品質取得                                             |
//+------------------------------------------------------------------+
double CBuildupDetector::GetBuildupQuality() {
    return m_currentBuildup.quality;
}

//+------------------------------------------------------------------+
//| ビルドアップ方向取得                                             |
//+------------------------------------------------------------------+
int CBuildupDetector::GetBuildupDirection() {
    return m_currentBuildup.direction;
}

//+------------------------------------------------------------------+
//| ビルドアップがアクティブか                                       |
//+------------------------------------------------------------------+
bool CBuildupDetector::IsBuildupActive() {
    return m_currentBuildup.isValid;
}

//+------------------------------------------------------------------+
//| ビルドアップが完成しているか                                     |
//+------------------------------------------------------------------+
bool CBuildupDetector::IsBuildupComplete() {
    if(!m_currentBuildup.isValid) return false;
    
    // 最新バーがビルドアップ範囲を超えたら完成
    double currentHigh = iHigh(m_symbol, m_timeframe, 0);
    double currentLow = iLow(m_symbol, m_timeframe, 0);
    
    if(currentHigh > m_currentBuildup.rangeHigh + PipsToPrice(2.0)) {
        return true;  // 上方ブレイク
    }
    if(currentLow < m_currentBuildup.rangeLow - PipsToPrice(2.0)) {
        return true;  // 下方ブレイク
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| 圧縮判定                                                         |
//+------------------------------------------------------------------+
bool CBuildupDetector::IsCompression() {
    return (m_currentBuildup.isValid && m_currentBuildup.compression > 0.6);
}

//+------------------------------------------------------------------+
//| 拡大判定                                                         |
//+------------------------------------------------------------------+
bool CBuildupDetector::IsExpansion() {
    if(!m_currentBuildup.isValid) return false;
    
    // 最新バーのレンジが平均の1.5倍以上
    double latestRange = PriceToPips(iHigh(m_symbol, m_timeframe, 0) - iLow(m_symbol, m_timeframe, 0));
    return (latestRange > m_currentBuildup.avgBarSize * 1.5);
}

//+------------------------------------------------------------------+
//| 圧縮率取得                                                       |
//+------------------------------------------------------------------+
double CBuildupDetector::GetCompressionRatio() {
    return m_currentBuildup.compression;
}

//+------------------------------------------------------------------+
//| 同時線割合取得                                                   |
//+------------------------------------------------------------------+
double CBuildupDetector::GetDojiPercentage() {
    return m_currentBuildup.dojiRatio * 100;
}

//+------------------------------------------------------------------+
//| ビルドアップ説明文取得                                           |
//+------------------------------------------------------------------+
string CBuildupDetector::GetBuildupDescription() {
    if(!m_currentBuildup.isValid) {
        return "No active buildup";
    }
    
    string desc = StringFormat(
        "Buildup: %d bars, Range: %.1f pips, Quality: %.0f%%, Direction: %s",
        m_currentBuildup.barCount,
        m_currentBuildup.rangeSize,
        m_currentBuildup.quality,
        (m_currentBuildup.direction > 0) ? "UP" : 
        (m_currentBuildup.direction < 0) ? "DOWN" : "NEUTRAL"
    );
    
    return desc;
}

//+------------------------------------------------------------------+
//| ビルドアップを描画                                               |
//+------------------------------------------------------------------+
void CBuildupDetector::DrawBuildup(string prefix, BuildupInfo &buildup, color clr) {
    if(!buildup.isValid) return;
    
    string name = prefix + "_buildup_" + TimeToString(TimeCurrent());
    
    // レンジボックスを描画
    datetime time1 = iTime(m_symbol, m_timeframe, buildup.startBar);
    datetime time2 = iTime(m_symbol, m_timeframe, buildup.endBar) + PeriodSeconds(m_timeframe);
    
    ObjectCreate(0, name + "_box", OBJ_RECTANGLE, 0, time1, buildup.rangeHigh, time2, buildup.rangeLow);
    ObjectSetInteger(0, name + "_box", OBJPROP_COLOR, clr);
    ObjectSetInteger(0, name + "_box", OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, name + "_box", OBJPROP_WIDTH, 1);
    ObjectSetInteger(0, name + "_box", OBJPROP_BACK, true);
    ObjectSetInteger(0, name + "_box", OBJPROP_FILL, true);
    
    // 中心線を描画
    ObjectCreate(0, name + "_center", OBJ_TREND, 0, time1, buildup.centerPrice, time2, buildup.centerPrice);
    ObjectSetInteger(0, name + "_center", OBJPROP_COLOR, clr);
    ObjectSetInteger(0, name + "_center", OBJPROP_STYLE, STYLE_DOT);
    ObjectSetInteger(0, name + "_center", OBJPROP_WIDTH, 1);
    ObjectSetInteger(0, name + "_center", OBJPROP_RAY_RIGHT, false);
}

//+------------------------------------------------------------------+