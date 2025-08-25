//+------------------------------------------------------------------+
//|                                              PBComboPlugin.mqh  |
//|                       パターンブレイク・コンボ戦略プラグイン     |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, FX5MinScalping"
#property link      "https://github.com/kapistock365/mt4-trading-tools"
#property strict

#include "DataStructures.mqh"
#include "MarketAnalyzer.mqh"
#include "BuildupDetector.mqh"

//+------------------------------------------------------------------+
//| パターンブレイク・コンボプラグインクラス                         |
//+------------------------------------------------------------------+
class CPBComboPlugin {
private:
    // コンポーネント
    CMarketAnalyzer* m_analyzer;
    CBuildupDetector* m_detector;
    
    // 設定パラメータ
    struct Settings {
        bool enabled;                   // プラグイン有効/無効
        int minFirstBuildup;           // 第1ビルドアップ最小バー数
        int maxFirstBuildup;           // 第1ビルドアップ最大バー数
        int minSecondBuildup;          // 第2ビルドアップ最小バー数
        int maxSecondBuildup;          // 第2ビルドアップ最大バー数
        double breakoutMinPips;        // ブレイクアウト最小pips
        double breakoutMaxPips;        // ブレイクアウト最大pips
        double buildupRangePips;       // ビルドアップレンジ幅
        int maxBarsBetween;            // ビルドアップ間の最大バー数
        double minComboStrength;       // 最小コンボ強度
        bool requireTrendAlignment;    // トレンド整合性必須
        double maxEMADistance;         // 最大EMA距離
    } m_settings;
    
    // 第1ブレイクアウト状態
    struct FirstBreakout {
        bool isActive;                 // アクティブフラグ
        int direction;                 // 方向（1:上, -1:下）
        double breakoutLevel;          // ブレイクアウトレベル
        double breakoutHigh;           // ブレイク後高値
        double breakoutLow;            // ブレイク後安値
        datetime breakoutTime;         // ブレイクアウト時刻
        int barsAfterBreakout;        // ブレイク後のバー数
        BuildupInfo buildup;           // ビルドアップ情報
        bool hasRetest;                // リテスト済みフラグ
    } m_firstBreakout;
    
    // 第2ビルドアップ状態
    struct SecondBuildup {
        bool isActive;                 // アクティブフラグ
        bool isDetected;               // 検出済みフラグ
        BuildupInfo buildup;           // ビルドアップ情報
        int barsInBuildup;             // ビルドアップ内バー数
        double compressionRatio;       // 圧縮比率
    } m_secondBuildup;
    
    // コンボ完成状態
    struct ComboState {
        bool isReady;                  // 準備完了フラグ
        int comboDirection;            // コンボ方向
        double entryLevel;             // エントリーレベル
        double stopLevel;              // ストップレベル
        double targetLevel;            // ターゲットレベル
        double comboStrength;          // コンボ強度
        datetime setupTime;            // セットアップ時刻
    } m_comboState;
    
    // 内部変数
    datetime m_lastSignalTime;
    int m_cooldownBars;
    
public:
    //+------------------------------------------------------------------+
    //| コンストラクタ                                                   |
    //+------------------------------------------------------------------+
    CPBComboPlugin() {
        m_analyzer = NULL;
        m_detector = NULL;
        InitializeSettings();
        ResetStates();
    }
    
    //+------------------------------------------------------------------+
    //| デストラクタ                                                     |
    //+------------------------------------------------------------------+
    ~CPBComboPlugin() {
        if(m_analyzer != NULL) delete m_analyzer;
        if(m_detector != NULL) delete m_detector;
    }
    
    //+------------------------------------------------------------------+
    //| 初期化                                                           |
    //+------------------------------------------------------------------+
    bool Initialize(bool enabled = true,
                   int minFirstBuildup = 3,
                   int maxFirstBuildup = 10,
                   int minSecondBuildup = 2,
                   int maxSecondBuildup = 8,
                   double breakoutMinPips = 2.0,
                   double breakoutMaxPips = 5.0,
                   double buildupRangePips = 8.0,
                   int maxBarsBetween = 15,
                   double minComboStrength = 60.0,
                   bool requireTrendAlignment = true,
                   double maxEMADistance = 20.0) {
        
        // 設定更新
        m_settings.enabled = enabled;
        m_settings.minFirstBuildup = minFirstBuildup;
        m_settings.maxFirstBuildup = maxFirstBuildup;
        m_settings.minSecondBuildup = minSecondBuildup;
        m_settings.maxSecondBuildup = maxSecondBuildup;
        m_settings.breakoutMinPips = breakoutMinPips;
        m_settings.breakoutMaxPips = breakoutMaxPips;
        m_settings.buildupRangePips = buildupRangePips;
        m_settings.maxBarsBetween = maxBarsBetween;
        m_settings.minComboStrength = minComboStrength;
        m_settings.requireTrendAlignment = requireTrendAlignment;
        m_settings.maxEMADistance = maxEMADistance;
        
        // コンポーネント初期化
        if(m_analyzer == NULL) m_analyzer = new CMarketAnalyzer();
        if(m_detector == NULL) m_detector = new CBuildupDetector();
        
        if(!m_analyzer.Initialize()) return false;
        if(!m_detector.Initialize()) return false;
        
        Print("PBComboPlugin initialized successfully");
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| メイン処理                                                       |
    //+------------------------------------------------------------------+
    void OnTick() {
        if(!m_settings.enabled) return;
        
        // 市場分析更新
        m_analyzer.UpdateAnalysis();
        
        // クールダウン管理
        if(m_cooldownBars > 0) {
            m_cooldownBars--;
            return;
        }
        
        // コンボ状態管理
        if(!m_firstBreakout.isActive) {
            // 第1ブレイクアウト検出
            DetectFirstBreakout();
        } else if(!m_secondBuildup.isDetected) {
            // 第2ビルドアップ検出
            TrackFirstBreakout();
            DetectSecondBuildup();
        } else if(!m_comboState.isReady) {
            // コンボ完成待ち
            TrackSecondBuildup();
            CheckComboCompletion();
        } else {
            // エントリー機会監視
            MonitorEntryOpportunity();
        }
    }
    
    //+------------------------------------------------------------------+
    //| シグナル取得                                                     |
    //+------------------------------------------------------------------+
    bool GetSignal(SignalInfo &signal) {
        if(!m_settings.enabled) return false;
        
        // コンボ完成後のシグナル
        if(m_comboState.isReady) {
            if(ValidateEntry()) {
                GenerateSignal(signal);
                return true;
            }
        }
        
        return false;
    }
    
    //+------------------------------------------------------------------+
    //| 可視化（デバッグ用）                                             |
    //+------------------------------------------------------------------+
    void DrawVisualization() {
        if(!m_settings.enabled) return;
        
        string prefix = "PBCombo_";
        
        // 第1ブレイクアウト描画
        if(m_firstBreakout.isActive) {
            // 第1ビルドアップボックス
            ObjectCreate(0, prefix + "FirstBuildup", OBJ_RECTANGLE, 0,
                       iTime(NULL, 0, m_firstBreakout.buildup.endBar),
                       m_firstBreakout.buildup.rangeHigh,
                       iTime(NULL, 0, m_firstBreakout.buildup.startBar),
                       m_firstBreakout.buildup.rangeLow);
            ObjectSetInteger(0, prefix + "FirstBuildup", OBJPROP_COLOR, clrLightBlue);
            ObjectSetInteger(0, prefix + "FirstBuildup", OBJPROP_BACK, true);
            
            // ブレイクアウトライン
            ObjectCreate(0, prefix + "BreakoutLevel", OBJ_HLINE, 0, 0, m_firstBreakout.breakoutLevel);
            ObjectSetInteger(0, prefix + "BreakoutLevel", OBJPROP_COLOR, clrBlue);
            ObjectSetInteger(0, prefix + "BreakoutLevel", OBJPROP_WIDTH, 2);
            ObjectSetInteger(0, prefix + "BreakoutLevel", OBJPROP_STYLE, STYLE_SOLID);
        }
        
        // 第2ビルドアップ描画
        if(m_secondBuildup.isDetected) {
            // 第2ビルドアップボックス
            ObjectCreate(0, prefix + "SecondBuildup", OBJ_RECTANGLE, 0,
                       iTime(NULL, 0, m_secondBuildup.buildup.endBar),
                       m_secondBuildup.buildup.rangeHigh,
                       iTime(NULL, 0, m_secondBuildup.buildup.startBar),
                       m_secondBuildup.buildup.rangeLow);
            ObjectSetInteger(0, prefix + "SecondBuildup", OBJPROP_COLOR, clrOrange);
            ObjectSetInteger(0, prefix + "SecondBuildup", OBJPROP_BACK, true);
            
            // 接続ライン
            ObjectCreate(0, prefix + "Connection", OBJ_TREND, 0,
                       m_firstBreakout.breakoutTime, m_firstBreakout.breakoutLevel,
                       iTime(NULL, 0, m_secondBuildup.buildup.startBar),
                       m_secondBuildup.buildup.centerPrice);
            ObjectSetInteger(0, prefix + "Connection", OBJPROP_COLOR, clrGray);
            ObjectSetInteger(0, prefix + "Connection", OBJPROP_STYLE, STYLE_DOT);
        }
        
        // コンボ完成時の表示
        if(m_comboState.isReady) {
            // エントリーゾーン
            double zoneHigh = m_comboState.entryLevel + PipsToPrice(1.0);
            double zoneLow = m_comboState.entryLevel - PipsToPrice(1.0);
            
            ObjectCreate(0, prefix + "EntryZone", OBJ_RECTANGLE, 0,
                       TimeCurrent() - 1800, zoneHigh,
                       TimeCurrent() + 1800, zoneLow);
            ObjectSetInteger(0, prefix + "EntryZone", OBJPROP_COLOR, clrLimeGreen);
            ObjectSetInteger(0, prefix + "EntryZone", OBJPROP_BACK, true);
            
            // ストップレベル
            ObjectCreate(0, prefix + "StopLevel", OBJ_HLINE, 0, 0, m_comboState.stopLevel);
            ObjectSetInteger(0, prefix + "StopLevel", OBJPROP_COLOR, clrRed);
            ObjectSetInteger(0, prefix + "StopLevel", OBJPROP_STYLE, STYLE_DASH);
            
            // ターゲットレベル
            ObjectCreate(0, prefix + "TargetLevel", OBJ_HLINE, 0, 0, m_comboState.targetLevel);
            ObjectSetInteger(0, prefix + "TargetLevel", OBJPROP_COLOR, clrGreen);
            ObjectSetInteger(0, prefix + "TargetLevel", OBJPROP_STYLE, STYLE_DASH);
            
            // コンボ強度表示
            ObjectCreate(0, prefix + "StrengthText", OBJ_TEXT, 0,
                       TimeCurrent(), m_comboState.entryLevel);
            ObjectSetString(0, prefix + "StrengthText", OBJPROP_TEXT,
                          StringFormat("Combo: %.0f%%", m_comboState.comboStrength));
            ObjectSetInteger(0, prefix + "StrengthText", OBJPROP_COLOR, clrWhite);
        }
    }
    
    //+------------------------------------------------------------------+
    //| クリーンアップ                                                   |
    //+------------------------------------------------------------------+
    void CleanupVisualization() {
        string prefix = "PBCombo_";
        int total = ObjectsTotal(0);
        
        for(int i = total - 1; i >= 0; i--) {
            string name = ObjectName(0, i);
            if(StringFind(name, prefix) == 0) {
                ObjectDelete(0, name);
            }
        }
    }
    
private:
    //+------------------------------------------------------------------+
    //| 設定初期化                                                       |
    //+------------------------------------------------------------------+
    void InitializeSettings() {
        m_settings.enabled = false;
        m_settings.minFirstBuildup = 3;
        m_settings.maxFirstBuildup = 10;
        m_settings.minSecondBuildup = 2;
        m_settings.maxSecondBuildup = 8;
        m_settings.breakoutMinPips = 2.0;
        m_settings.breakoutMaxPips = 5.0;
        m_settings.buildupRangePips = 8.0;
        m_settings.maxBarsBetween = 15;
        m_settings.minComboStrength = 60.0;
        m_settings.requireTrendAlignment = true;
        m_settings.maxEMADistance = 20.0;
        
        m_lastSignalTime = 0;
        m_cooldownBars = 0;
    }
    
    //+------------------------------------------------------------------+
    //| 状態リセット                                                     |
    //+------------------------------------------------------------------+
    void ResetStates() {
        // 第1ブレイクアウト状態リセット
        m_firstBreakout.isActive = false;
        m_firstBreakout.direction = 0;
        m_firstBreakout.breakoutLevel = 0;
        m_firstBreakout.breakoutHigh = 0;
        m_firstBreakout.breakoutLow = 0;
        m_firstBreakout.breakoutTime = 0;
        m_firstBreakout.barsAfterBreakout = 0;
        m_firstBreakout.hasRetest = false;
        
        // 第2ビルドアップ状態リセット
        m_secondBuildup.isActive = false;
        m_secondBuildup.isDetected = false;
        m_secondBuildup.barsInBuildup = 0;
        m_secondBuildup.compressionRatio = 0;
        
        // コンボ状態リセット
        m_comboState.isReady = false;
        m_comboState.comboDirection = 0;
        m_comboState.entryLevel = 0;
        m_comboState.stopLevel = 0;
        m_comboState.targetLevel = 0;
        m_comboState.comboStrength = 0;
        m_comboState.setupTime = 0;
    }
    
    //+------------------------------------------------------------------+
    //| 第1ブレイクアウト検出                                            |
    //+------------------------------------------------------------------+
    void DetectFirstBreakout() {
        // ビルドアップ検出
        if(!m_detector.DetectBuildup()) return;
        
        BuildupInfo buildup = m_detector.GetLastBuildup();
        if(!buildup.isValid) return;
        
        // ビルドアップバー数チェック
        if(buildup.barCount < m_settings.minFirstBuildup ||
           buildup.barCount > m_settings.maxFirstBuildup) return;
        
        // レンジサイズチェック
        if(buildup.rangeSize > m_settings.buildupRangePips) return;
        
        double currentPrice = iClose(NULL, 0, 0);
        double breakoutPips = PipsToPrice(m_settings.breakoutMinPips);
        
        // 上方ブレイクアウト
        if(currentPrice > buildup.rangeHigh + breakoutPips) {
            // ブレイクアウト距離チェック
            double breakDistance = PriceToPips(currentPrice - buildup.rangeHigh);
            if(breakDistance > m_settings.breakoutMaxPips) return;
            
            // 第1ブレイクアウト状態設定
            m_firstBreakout.isActive = true;
            m_firstBreakout.direction = 1;
            m_firstBreakout.breakoutLevel = buildup.rangeHigh;
            m_firstBreakout.breakoutHigh = currentPrice;
            m_firstBreakout.breakoutLow = buildup.rangeHigh;
            m_firstBreakout.breakoutTime = TimeCurrent();
            m_firstBreakout.barsAfterBreakout = 0;
            m_firstBreakout.buildup = buildup;
            m_firstBreakout.hasRetest = false;
            
            Print("First bullish breakout detected at ", currentPrice);
        }
        // 下方ブレイクアウト
        else if(currentPrice < buildup.rangeLow - breakoutPips) {
            // ブレイクアウト距離チェック
            double breakDistance = PriceToPips(buildup.rangeLow - currentPrice);
            if(breakDistance > m_settings.breakoutMaxPips) return;
            
            // 第1ブレイクアウト状態設定
            m_firstBreakout.isActive = true;
            m_firstBreakout.direction = -1;
            m_firstBreakout.breakoutLevel = buildup.rangeLow;
            m_firstBreakout.breakoutHigh = buildup.rangeLow;
            m_firstBreakout.breakoutLow = currentPrice;
            m_firstBreakout.breakoutTime = TimeCurrent();
            m_firstBreakout.barsAfterBreakout = 0;
            m_firstBreakout.buildup = buildup;
            m_firstBreakout.hasRetest = false;
            
            Print("First bearish breakout detected at ", currentPrice);
        }
    }
    
    //+------------------------------------------------------------------+
    //| 第1ブレイクアウト追跡                                            |
    //+------------------------------------------------------------------+
    void TrackFirstBreakout() {
        m_firstBreakout.barsAfterBreakout++;
        
        // タイムアウトチェック
        if(m_firstBreakout.barsAfterBreakout > m_settings.maxBarsBetween + 10) {
            Print("First breakout timeout - resetting");
            ResetStates();
            return;
        }
        
        double currentHigh = iHigh(NULL, 0, 0);
        double currentLow = iLow(NULL, 0, 0);
        
        // ブレイクアウト範囲更新
        if(m_firstBreakout.direction > 0) {
            m_firstBreakout.breakoutHigh = MathMax(m_firstBreakout.breakoutHigh, currentHigh);
            
            // リテストチェック
            if(!m_firstBreakout.hasRetest && 
               currentLow <= m_firstBreakout.breakoutLevel + PipsToPrice(1.0)) {
                m_firstBreakout.hasRetest = true;
                Print("First breakout retest detected");
            }
        } else {
            m_firstBreakout.breakoutLow = MathMin(m_firstBreakout.breakoutLow, currentLow);
            
            // リテストチェック
            if(!m_firstBreakout.hasRetest && 
               currentHigh >= m_firstBreakout.breakoutLevel - PipsToPrice(1.0)) {
                m_firstBreakout.hasRetest = true;
                Print("First breakout retest detected");
            }
        }
    }
    
    //+------------------------------------------------------------------+
    //| 第2ビルドアップ検出                                              |
    //+------------------------------------------------------------------+
    void DetectSecondBuildup() {
        // 最小間隔チェック
        if(m_firstBreakout.barsAfterBreakout < 2) return;
        
        // 第2ビルドアップを探す
        for(int startBar = 1; startBar <= m_settings.maxBarsBetween; startBar++) {
            if(CheckSecondBuildup(startBar)) {
                m_secondBuildup.isDetected = true;
                m_secondBuildup.isActive = true;
                m_secondBuildup.barsInBuildup = 0;
                
                // 圧縮比率計算
                double firstRange = m_firstBreakout.buildup.rangeSize;
                double secondRange = m_secondBuildup.buildup.rangeSize;
                m_secondBuildup.compressionRatio = secondRange / firstRange;
                
                Print("Second buildup detected - compression ratio: ",
                      m_secondBuildup.compressionRatio);
                break;
            }
        }
    }
    
    //+------------------------------------------------------------------+
    //| 第2ビルドアップチェック                                          |
    //+------------------------------------------------------------------+
    bool CheckSecondBuildup(int startBar) {
        // ビルドアップパターン検出
        double rangeHigh = iHigh(NULL, 0, startBar);
        double rangeLow = iLow(NULL, 0, startBar);
        int barCount = 1;
        
        for(int i = startBar + 1; i <= startBar + m_settings.maxSecondBuildup; i++) {
            if(i >= Bars) break;
            
            double high = iHigh(NULL, 0, i);
            double low = iLow(NULL, 0, i);
            
            // レンジ拡大チェック
            if(high > rangeHigh + PipsToPrice(1.0) || 
               low < rangeLow - PipsToPrice(1.0)) {
                break;
            }
            
            rangeHigh = MathMax(rangeHigh, high);
            rangeLow = MathMin(rangeLow, low);
            barCount++;
        }
        
        // 最小バー数チェック
        if(barCount < m_settings.minSecondBuildup) return false;
        
        // レンジサイズチェック
        double rangeSize = PriceToPips(rangeHigh - rangeLow);
        if(rangeSize > m_settings.buildupRangePips) return false;
        
        // 位置チェック（第1ブレイクアウトレベル付近）
        double centerPrice = (rangeHigh + rangeLow) / 2;
        double distanceFromBreakout = MathAbs(centerPrice - m_firstBreakout.breakoutLevel);
        
        if(PriceToPips(distanceFromBreakout) > 5.0) return false;
        
        // 第2ビルドアップ情報設定
        m_secondBuildup.buildup.startBar = startBar;
        m_secondBuildup.buildup.endBar = startBar + barCount - 1;
        m_secondBuildup.buildup.barCount = barCount;
        m_secondBuildup.buildup.rangeHigh = rangeHigh;
        m_secondBuildup.buildup.rangeLow = rangeLow;
        m_secondBuildup.buildup.rangeSize = rangeSize;
        m_secondBuildup.buildup.centerPrice = centerPrice;
        m_secondBuildup.buildup.isValid = true;
        
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| 第2ビルドアップ追跡                                              |
    //+------------------------------------------------------------------+
    void TrackSecondBuildup() {
        if(!m_secondBuildup.isActive) return;
        
        m_secondBuildup.barsInBuildup++;
        
        // ビルドアップ範囲更新
        double currentHigh = iHigh(NULL, 0, 0);
        double currentLow = iLow(NULL, 0, 0);
        
        // ブレイクアウトチェック
        double breakoutPips = PipsToPrice(m_settings.breakoutMinPips);
        
        if(currentHigh > m_secondBuildup.buildup.rangeHigh + breakoutPips ||
           currentLow < m_secondBuildup.buildup.rangeLow - breakoutPips) {
            m_secondBuildup.isActive = false;
            Print("Second buildup breakout detected");
        }
    }
    
    //+------------------------------------------------------------------+
    //| コンボ完成チェック                                               |
    //+------------------------------------------------------------------+
    void CheckComboCompletion() {
        if(!m_secondBuildup.isDetected || m_secondBuildup.isActive) return;
        
        double currentPrice = iClose(NULL, 0, 0);
        double breakoutPips = PipsToPrice(m_settings.breakoutMinPips);
        
        // コンボ方向判定
        if(m_firstBreakout.direction > 0) {
            // 上昇コンボ: 第2ビルドアップを上方ブレイク
            if(currentPrice > m_secondBuildup.buildup.rangeHigh + breakoutPips) {
                // コンボ強度計算
                double strength = CalculateComboStrength();
                if(strength < m_settings.minComboStrength) return;
                
                // コンボ完成
                m_comboState.isReady = true;
                m_comboState.comboDirection = 1;
                m_comboState.entryLevel = currentPrice;
                m_comboState.stopLevel = m_secondBuildup.buildup.rangeLow - PipsToPrice(2.0);
                m_comboState.targetLevel = currentPrice + PipsToPrice(20.0);
                m_comboState.comboStrength = strength;
                m_comboState.setupTime = TimeCurrent();
                
                Print("Bullish combo completed - strength: ", strength);
            }
        } else {
            // 下降コンボ: 第2ビルドアップを下方ブレイク
            if(currentPrice < m_secondBuildup.buildup.rangeLow - breakoutPips) {
                // コンボ強度計算
                double strength = CalculateComboStrength();
                if(strength < m_settings.minComboStrength) return;
                
                // コンボ完成
                m_comboState.isReady = true;
                m_comboState.comboDirection = -1;
                m_comboState.entryLevel = currentPrice;
                m_comboState.stopLevel = m_secondBuildup.buildup.rangeHigh + PipsToPrice(2.0);
                m_comboState.targetLevel = currentPrice - PipsToPrice(20.0);
                m_comboState.comboStrength = strength;
                m_comboState.setupTime = TimeCurrent();
                
                Print("Bearish combo completed - strength: ", strength);
            }
        }
    }
    
    //+------------------------------------------------------------------+
    //| エントリー機会監視                                               |
    //+------------------------------------------------------------------+
    void MonitorEntryOpportunity() {
        // タイムアウトチェック（5分）
        if(TimeCurrent() - m_comboState.setupTime > 300) {
            Print("Combo entry timeout - resetting");
            ResetStates();
            return;
        }
        
        // エントリー条件は GetSignal で処理
    }
    
    //+------------------------------------------------------------------+
    //| エントリー検証                                                   |
    //+------------------------------------------------------------------+
    bool ValidateEntry() {
        // トレンド整合性チェック
        if(m_settings.requireTrendAlignment) {
            MarketCondition condition = m_analyzer.GetMarketCondition();
            if(condition.trendDirection != m_comboState.comboDirection) {
                return false;
            }
        }
        
        // EMA距離チェック
        double ema25 = iMA(NULL, 0, 25, 0, MODE_EMA, PRICE_CLOSE, 0);
        double currentPrice = iClose(NULL, 0, 0);
        double distance = MathAbs(currentPrice - ema25);
        
        if(PriceToPips(distance) > m_settings.maxEMADistance) {
            return false;
        }
        
        // スプレッドチェック
        MarketCondition condition = m_analyzer.GetMarketCondition();
        if(condition.currentSpread > 2.0) return false;
        
        // 時間帯チェック
        if(!m_analyzer.IsOptimalTradingTime()) return false;
        
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| シグナル生成                                                     |
    //+------------------------------------------------------------------+
    void GenerateSignal(SignalInfo &signal) {
        signal.signalType = m_comboState.comboDirection;
        signal.setupName = "PB Combo";
        signal.entryPrice = iClose(NULL, 0, 0);
        signal.stopLoss = m_comboState.stopLevel;
        signal.takeProfit = m_comboState.targetLevel;
        signal.signalStrength = m_comboState.comboStrength;
        
        // 理由説明
        signal.reason = StringFormat("Double buildup combo (compression: %.2f)",
                                   m_secondBuildup.compressionRatio);
        
        signal.generatedTime = TimeCurrent();
        signal.expirationTime = TimeCurrent() + 300; // 5分間有効
        signal.isValid = true;
        
        // 追加情報
        signal.additionalInfo = StringFormat(
            "1st: %d bars (%.1f pips), 2nd: %d bars (%.1f pips), Strength: %.0f%%",
            m_firstBreakout.buildup.barCount,
            m_firstBreakout.buildup.rangeSize,
            m_secondBuildup.buildup.barCount,
            m_secondBuildup.buildup.rangeSize,
            m_comboState.comboStrength
        );
        
        // クールダウン設定
        m_lastSignalTime = TimeCurrent();
        m_cooldownBars = 6; // 30分クールダウン
        
        // 状態リセット
        ResetStates();
    }
    
    //+------------------------------------------------------------------+
    //| コンボ強度計算                                                   |
    //+------------------------------------------------------------------+
    double CalculateComboStrength() {
        double strength = 40; // 基本スコア
        
        // 圧縮比率評価（第2が第1より狭い方が良い）
        if(m_secondBuildup.compressionRatio < 0.7) {
            strength += 20;
        } else if(m_secondBuildup.compressionRatio < 0.9) {
            strength += 15;
        } else {
            strength += 10;
        }
        
        // リテスト評価
        if(m_firstBreakout.hasRetest) {
            strength += 15;
        }
        
        // ビルドアップ品質
        double firstQuality = m_detector.EvaluateQuality(m_firstBreakout.buildup);
        double secondQuality = m_detector.EvaluateQuality(m_secondBuildup.buildup);
        strength += (firstQuality + secondQuality) * 0.15;
        
        // バー数バランス評価
        double barRatio = (double)m_secondBuildup.buildup.barCount / 
                         m_firstBreakout.buildup.barCount;
        if(barRatio >= 0.4 && barRatio <= 0.8) {
            strength += 10; // 理想的なバランス
        }
        
        return MathMin(100, strength);
    }
};

//+------------------------------------------------------------------+