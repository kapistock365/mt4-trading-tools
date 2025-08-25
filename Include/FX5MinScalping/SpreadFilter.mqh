//+------------------------------------------------------------------+
//|                                                 SpreadFilter.mqh |
//|                               スプレッドフィルターモジュール      |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, FX5MinScalping"
#property link      "https://github.com/kapistock365/mt4-trading-tools"
#property strict

#include "DataStructures.mqh"

//+------------------------------------------------------------------+
//| スプレッド状態                                                   |
//+------------------------------------------------------------------+
enum ENUM_SPREAD_CONDITION {
    SPREAD_EXCELLENT = 0,    // 優良（0-1.0 pips）
    SPREAD_GOOD = 1,        // 良好（1.0-1.5 pips）
    SPREAD_NORMAL = 2,      // 通常（1.5-2.0 pips）
    SPREAD_WIDE = 3,        // 拡大（2.0-3.0 pips）
    SPREAD_EXTREME = 4      // 極大（3.0+ pips）
};

//+------------------------------------------------------------------+
//| スプレッドフィルタークラス                                       |
//+------------------------------------------------------------------+
class CSpreadFilter {
private:
    // 設定パラメータ
    struct Settings {
        bool enabled;                   // フィルター有効/無効
        double maxSpreadPips;          // 最大許容スプレッド（pips）
        double preferredSpreadPips;    // 推奨スプレッド（pips）
        bool useAdaptiveFilter;        // 適応型フィルター使用
        int averagePeriod;             // 平均計算期間（分）
        double adaptiveMultiplier;     // 適応型乗数
        bool alertOnWideSpread;        // スプレッド拡大時アラート
        double alertThresholdPips;     // アラート閾値（pips）
        int historySize;               // 履歴サイズ
        bool logSpreadData;            // スプレッドデータ記録
    } m_settings;
    
    // スプレッド統計
    struct SpreadStats {
        double currentSpread;          // 現在のスプレッド（pips）
        double averageSpread;          // 平均スプレッド
        double minSpread;              // 最小スプレッド
        double maxSpread;              // 最大スプレッド
        double stdDeviation;           // 標準偏差
        int samplesCount;              // サンプル数
        datetime lastUpdateTime;       // 最終更新時刻
    } m_stats;
    
    // スプレッド履歴
    struct SpreadHistory {
        double spread;
        datetime time;
    };
    SpreadHistory m_history[];
    int m_historyIndex;
    
    // 内部変数
    datetime m_lastAlertTime;
    ENUM_SPREAD_CONDITION m_currentCondition;
    bool m_isTradingAllowed;
    string m_restrictionReason;
    double m_adaptiveThreshold;
    
    // ピーク時間帯（スプレッドが広がりやすい時間）
    struct PeakTime {
        int hour;
        int minute;
        int duration;  // 分
        double expectedSpread;
    };
    PeakTime m_peakTimes[];
    int m_peakTimeCount;
    
public:
    //+------------------------------------------------------------------+
    //| コンストラクタ                                                   |
    //+------------------------------------------------------------------+
    CSpreadFilter() {
        InitializeSettings();
        InitializePeakTimes();
        ResetStatistics();
        ArrayResize(m_history, 1000);
        m_historyIndex = 0;
        m_lastAlertTime = 0;
        m_currentCondition = SPREAD_NORMAL;
        m_isTradingAllowed = true;
        m_restrictionReason = "";
        m_adaptiveThreshold = 2.0;
    }
    
    //+------------------------------------------------------------------+
    //| 初期化                                                           |
    //+------------------------------------------------------------------+
    bool Initialize(bool enabled = true,
                   double maxSpreadPips = 2.0,
                   double preferredSpreadPips = 1.5,
                   bool useAdaptiveFilter = true,
                   int averagePeriod = 30,
                   double adaptiveMultiplier = 1.5,
                   bool alertOnWideSpread = true,
                   double alertThresholdPips = 3.0,
                   int historySize = 1000,
                   bool logSpreadData = false) {
        
        m_settings.enabled = enabled;
        m_settings.maxSpreadPips = maxSpreadPips;
        m_settings.preferredSpreadPips = preferredSpreadPips;
        m_settings.useAdaptiveFilter = useAdaptiveFilter;
        m_settings.averagePeriod = averagePeriod;
        m_settings.adaptiveMultiplier = adaptiveMultiplier;
        m_settings.alertOnWideSpread = alertOnWideSpread;
        m_settings.alertThresholdPips = alertThresholdPips;
        m_settings.historySize = historySize;
        m_settings.logSpreadData = logSpreadData;
        
        ArrayResize(m_history, historySize);
        
        UpdateSpread();
        
        Print("SpreadFilter initialized successfully");
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| 取引可能チェック                                                 |
    //+------------------------------------------------------------------+
    bool IsTradingAllowed() {
        if(!m_settings.enabled) return true;
        
        UpdateSpread();
        return m_isTradingAllowed;
    }
    
    //+------------------------------------------------------------------+
    //| 現在のスプレッド取得（pips）                                     |
    //+------------------------------------------------------------------+
    double GetCurrentSpread() {
        UpdateSpread();
        return m_stats.currentSpread;
    }
    
    //+------------------------------------------------------------------+
    //| スプレッド状態取得                                               |
    //+------------------------------------------------------------------+
    ENUM_SPREAD_CONDITION GetSpreadCondition() {
        UpdateSpread();
        return m_currentCondition;
    }
    
    //+------------------------------------------------------------------+
    //| スプレッド状態名取得                                             |
    //+------------------------------------------------------------------+
    string GetConditionName() {
        switch(m_currentCondition) {
            case SPREAD_EXCELLENT: return "Excellent";
            case SPREAD_GOOD:      return "Good";
            case SPREAD_NORMAL:    return "Normal";
            case SPREAD_WIDE:      return "Wide";
            case SPREAD_EXTREME:   return "Extreme";
            default:              return "Unknown";
        }
    }
    
    //+------------------------------------------------------------------+
    //| 制限理由取得                                                     |
    //+------------------------------------------------------------------+
    string GetRestrictionReason() {
        return m_restrictionReason;
    }
    
    //+------------------------------------------------------------------+
    //| 統計情報取得                                                     |
    //+------------------------------------------------------------------+
    SpreadStats GetStatistics() {
        UpdateStatistics();
        return m_stats;
    }
    
    //+------------------------------------------------------------------+
    //| 統計文字列取得                                                   |
    //+------------------------------------------------------------------+
    void GetStatisticsString(string &stats[]) {
        UpdateStatistics();
        
        ArrayResize(stats, 10);
        
        stats[0] = "=== Spread Filter Status ===";
        stats[1] = "Enabled: " + (m_settings.enabled ? "Yes" : "No");
        stats[2] = StringFormat("Current: %.2f pips (%s)", 
                              m_stats.currentSpread, GetConditionName());
        stats[3] = StringFormat("Average: %.2f pips", m_stats.averageSpread);
        stats[4] = StringFormat("Min/Max: %.2f / %.2f pips", 
                              m_stats.minSpread, m_stats.maxSpread);
        stats[5] = StringFormat("Std Dev: %.2f", m_stats.stdDeviation);
        stats[6] = "Trading: " + (m_isTradingAllowed ? "Allowed" : "Blocked");
        
        if(!m_isTradingAllowed && m_restrictionReason != "") {
            stats[7] = "Reason: " + m_restrictionReason;
        } else {
            stats[7] = StringFormat("Threshold: %.2f pips", 
                                  m_settings.useAdaptiveFilter ? 
                                  m_adaptiveThreshold : m_settings.maxSpreadPips);
        }
        
        stats[8] = "Adaptive: " + (m_settings.useAdaptiveFilter ? "Active" : "Inactive");
        stats[9] = "Samples: " + IntegerToString(m_stats.samplesCount);
    }
    
    //+------------------------------------------------------------------+
    //| スプレッド予測（時間帯ベース）                                   |
    //+------------------------------------------------------------------+
    double GetExpectedSpread(datetime targetTime = 0) {
        if(targetTime == 0) targetTime = TimeCurrent();
        
        MqlDateTime dt;
        TimeToStruct(targetTime, dt);
        
        // ピーク時間チェック
        for(int i = 0; i < m_peakTimeCount; i++) {
            int peakMinutes = m_peakTimes[i].hour * 60 + m_peakTimes[i].minute;
            int currentMinutes = dt.hour * 60 + dt.min;
            
            if(MathAbs(currentMinutes - peakMinutes) <= m_peakTimes[i].duration) {
                return m_peakTimes[i].expectedSpread;
            }
        }
        
        // セッション別基本スプレッド
        if(dt.hour >= 7 && dt.hour < 16) {
            // ロンドンセッション
            return 1.0;
        } else if(dt.hour >= 12 && dt.hour < 21) {
            // NYセッション
            return 1.2;
        } else if(dt.hour >= 21 || dt.hour < 7) {
            // アジア/オフピーク
            return 1.8;
        }
        
        return 1.5; // デフォルト
    }
    
    //+------------------------------------------------------------------+
    //| スプレッド履歴取得                                               |
    //+------------------------------------------------------------------+
    bool GetSpreadHistory(double &spreads[], datetime &times[], int count = 100) {
        int available = MathMin(count, m_historyIndex);
        if(available <= 0) return false;
        
        ArrayResize(spreads, available);
        ArrayResize(times, available);
        
        int startIdx = m_historyIndex - available;
        for(int i = 0; i < available; i++) {
            spreads[i] = m_history[startIdx + i].spread;
            times[i] = m_history[startIdx + i].time;
        }
        
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| CSVエクスポート                                                  |
    //+------------------------------------------------------------------+
    bool ExportToCSV(string filename) {
        if(!m_settings.logSpreadData) return false;
        
        int handle = FileOpen(filename, FILE_WRITE|FILE_CSV);
        if(handle == INVALID_HANDLE) return false;
        
        // ヘッダー
        FileWrite(handle, "DateTime", "Spread(pips)", "Condition", "Average", "StdDev");
        
        // データ
        for(int i = 0; i < m_historyIndex; i++) {
            FileWrite(handle, 
                     TimeToString(m_history[i].time, TIME_DATE|TIME_SECONDS),
                     DoubleToString(m_history[i].spread, 2),
                     GetConditionNameBySpread(m_history[i].spread),
                     DoubleToString(m_stats.averageSpread, 2),
                     DoubleToString(m_stats.stdDeviation, 2));
        }
        
        FileClose(handle);
        Print("Spread data exported to ", filename);
        return true;
    }
    
private:
    //+------------------------------------------------------------------+
    //| 設定初期化                                                       |
    //+------------------------------------------------------------------+
    void InitializeSettings() {
        m_settings.enabled = false;
        m_settings.maxSpreadPips = 2.0;
        m_settings.preferredSpreadPips = 1.5;
        m_settings.useAdaptiveFilter = true;
        m_settings.averagePeriod = 30;
        m_settings.adaptiveMultiplier = 1.5;
        m_settings.alertOnWideSpread = true;
        m_settings.alertThresholdPips = 3.0;
        m_settings.historySize = 1000;
        m_settings.logSpreadData = false;
    }
    
    //+------------------------------------------------------------------+
    //| ピーク時間初期化                                                 |
    //+------------------------------------------------------------------+
    void InitializePeakTimes() {
        m_peakTimeCount = 0;
        ArrayResize(m_peakTimes, 10);
        
        // マーケットオープン時
        AddPeakTime(0, 0, 30, 2.5);    // アジアオープン
        AddPeakTime(7, 0, 30, 2.0);    // ロンドンオープン
        AddPeakTime(12, 0, 30, 2.2);   // NYオープン
        
        // マーケットクローズ時
        AddPeakTime(16, 0, 30, 1.8);   // ロンドンクローズ
        AddPeakTime(21, 0, 30, 2.5);   // NYクローズ
        
        // ニュース時間（一般的な時間）
        AddPeakTime(8, 30, 15, 3.0);   // 欧州指標
        AddPeakTime(13, 30, 15, 3.0);  // 米国指標
    }
    
    //+------------------------------------------------------------------+
    //| ピーク時間追加                                                   |
    //+------------------------------------------------------------------+
    void AddPeakTime(int hour, int minute, int duration, double expectedSpread) {
        if(m_peakTimeCount >= ArraySize(m_peakTimes)) return;
        
        m_peakTimes[m_peakTimeCount].hour = hour;
        m_peakTimes[m_peakTimeCount].minute = minute;
        m_peakTimes[m_peakTimeCount].duration = duration;
        m_peakTimes[m_peakTimeCount].expectedSpread = expectedSpread;
        
        m_peakTimeCount++;
    }
    
    //+------------------------------------------------------------------+
    //| 統計リセット                                                     |
    //+------------------------------------------------------------------+
    void ResetStatistics() {
        m_stats.currentSpread = 0;
        m_stats.averageSpread = 0;
        m_stats.minSpread = 999;
        m_stats.maxSpread = 0;
        m_stats.stdDeviation = 0;
        m_stats.samplesCount = 0;
        m_stats.lastUpdateTime = 0;
    }
    
    //+------------------------------------------------------------------+
    //| スプレッド更新                                                   |
    //+------------------------------------------------------------------+
    void UpdateSpread() {
        // 現在のスプレッド取得
        double spreadPoints = MarketInfo(Symbol(), MODE_SPREAD);
        m_stats.currentSpread = PriceToPips(spreadPoints * Point);
        m_stats.lastUpdateTime = TimeCurrent();
        
        // 履歴に追加
        AddToHistory(m_stats.currentSpread);
        
        // 統計更新
        UpdateStatistics();
        
        // 状態判定
        UpdateCondition();
        
        // 取引可否判定
        CheckTradingAllowed();
        
        // アラートチェック
        if(m_settings.alertOnWideSpread) {
            CheckAlert();
        }
        
        // ログ出力
        if(m_settings.logSpreadData) {
            LogSpreadData();
        }
    }
    
    //+------------------------------------------------------------------+
    //| 履歴追加                                                         |
    //+------------------------------------------------------------------+
    void AddToHistory(double spread) {
        if(m_historyIndex >= ArraySize(m_history)) {
            // 古いデータを削除して新しいデータを追加
            for(int i = 0; i < ArraySize(m_history) - 1; i++) {
                m_history[i] = m_history[i + 1];
            }
            m_historyIndex = ArraySize(m_history) - 1;
        }
        
        m_history[m_historyIndex].spread = spread;
        m_history[m_historyIndex].time = TimeCurrent();
        m_historyIndex++;
    }
    
    //+------------------------------------------------------------------+
    //| 統計更新                                                         |
    //+------------------------------------------------------------------+
    void UpdateStatistics() {
        if(m_historyIndex == 0) return;
        
        // 計算期間の決定
        datetime periodStart = TimeCurrent() - m_settings.averagePeriod * 60;
        int startIdx = 0;
        
        for(int i = m_historyIndex - 1; i >= 0; i--) {
            if(m_history[i].time < periodStart) {
                startIdx = i + 1;
                break;
            }
        }
        
        if(startIdx >= m_historyIndex) return;
        
        // 平均、最小、最大計算
        double sum = 0;
        m_stats.minSpread = 999;
        m_stats.maxSpread = 0;
        m_stats.samplesCount = 0;
        
        for(int i = startIdx; i < m_historyIndex; i++) {
            double spread = m_history[i].spread;
            sum += spread;
            m_stats.minSpread = MathMin(m_stats.minSpread, spread);
            m_stats.maxSpread = MathMax(m_stats.maxSpread, spread);
            m_stats.samplesCount++;
        }
        
        if(m_stats.samplesCount > 0) {
            m_stats.averageSpread = sum / m_stats.samplesCount;
            
            // 標準偏差計算
            double sumSquared = 0;
            for(int i = startIdx; i < m_historyIndex; i++) {
                double diff = m_history[i].spread - m_stats.averageSpread;
                sumSquared += diff * diff;
            }
            m_stats.stdDeviation = MathSqrt(sumSquared / m_stats.samplesCount);
        }
        
        // 適応型閾値更新
        if(m_settings.useAdaptiveFilter && m_stats.samplesCount > 10) {
            m_adaptiveThreshold = m_stats.averageSpread + 
                                (m_stats.stdDeviation * m_settings.adaptiveMultiplier);
            m_adaptiveThreshold = MathMax(m_adaptiveThreshold, m_settings.preferredSpreadPips);
            m_adaptiveThreshold = MathMin(m_adaptiveThreshold, m_settings.maxSpreadPips * 1.5);
        }
    }
    
    //+------------------------------------------------------------------+
    //| 状態更新                                                         |
    //+------------------------------------------------------------------+
    void UpdateCondition() {
        if(m_stats.currentSpread <= 1.0) {
            m_currentCondition = SPREAD_EXCELLENT;
        } else if(m_stats.currentSpread <= 1.5) {
            m_currentCondition = SPREAD_GOOD;
        } else if(m_stats.currentSpread <= 2.0) {
            m_currentCondition = SPREAD_NORMAL;
        } else if(m_stats.currentSpread <= 3.0) {
            m_currentCondition = SPREAD_WIDE;
        } else {
            m_currentCondition = SPREAD_EXTREME;
        }
    }
    
    //+------------------------------------------------------------------+
    //| 取引可否チェック                                                 |
    //+------------------------------------------------------------------+
    void CheckTradingAllowed() {
        m_isTradingAllowed = true;
        m_restrictionReason = "";
        
        // 基本閾値チェック
        if(m_stats.currentSpread > m_settings.maxSpreadPips) {
            m_isTradingAllowed = false;
            m_restrictionReason = StringFormat("Spread too wide: %.2f > %.2f pips",
                                             m_stats.currentSpread, 
                                             m_settings.maxSpreadPips);
            return;
        }
        
        // 適応型フィルターチェック
        if(m_settings.useAdaptiveFilter) {
            if(m_stats.currentSpread > m_adaptiveThreshold) {
                m_isTradingAllowed = false;
                m_restrictionReason = StringFormat("Spread exceeds adaptive threshold: %.2f > %.2f pips",
                                                 m_stats.currentSpread, 
                                                 m_adaptiveThreshold);
                return;
            }
        }
        
        // 極端な拡大チェック
        if(m_currentCondition == SPREAD_EXTREME) {
            m_isTradingAllowed = false;
            m_restrictionReason = "Extreme spread condition";
            return;
        }
    }
    
    //+------------------------------------------------------------------+
    //| アラートチェック                                                 |
    //+------------------------------------------------------------------+
    void CheckAlert() {
        if(m_stats.currentSpread >= m_settings.alertThresholdPips) {
            if(TimeCurrent() - m_lastAlertTime > 300) { // 5分間隔
                Alert(StringFormat("Wide spread detected: %.2f pips", 
                                 m_stats.currentSpread));
                m_lastAlertTime = TimeCurrent();
            }
        }
    }
    
    //+------------------------------------------------------------------+
    //| スプレッドデータログ                                             |
    //+------------------------------------------------------------------+
    void LogSpreadData() {
        static datetime lastLogTime = 0;
        
        // 1分ごとにログ
        if(TimeCurrent() - lastLogTime >= 60) {
            Print(StringFormat("Spread: Current=%.2f, Avg=%.2f, Min=%.2f, Max=%.2f, StdDev=%.2f",
                            m_stats.currentSpread,
                            m_stats.averageSpread,
                            m_stats.minSpread,
                            m_stats.maxSpread,
                            m_stats.stdDeviation));
            lastLogTime = TimeCurrent();
        }
    }
    
    //+------------------------------------------------------------------+
    //| スプレッドによる状態名取得                                       |
    //+------------------------------------------------------------------+
    string GetConditionNameBySpread(double spread) {
        if(spread <= 1.0) return "Excellent";
        else if(spread <= 1.5) return "Good";
        else if(spread <= 2.0) return "Normal";
        else if(spread <= 3.0) return "Wide";
        else return "Extreme";
    }
};

//+------------------------------------------------------------------+