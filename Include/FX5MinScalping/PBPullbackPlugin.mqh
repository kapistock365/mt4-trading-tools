//+------------------------------------------------------------------+
//|                                            PBPullbackPlugin.mqh |
//|                     パターンブレイク・プルバック戦略プラグイン   |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, FX5MinScalping"
#property link      "https://github.com/kapistock365/mt4-trading-tools"
#property strict

#include "DataStructures.mqh"
#include "MarketAnalyzer.mqh"
#include "BuildupDetector.mqh"

//+------------------------------------------------------------------+
//| パターンブレイク・プルバックプラグインクラス                     |
//+------------------------------------------------------------------+
class CPBPullbackPlugin {
private:
    // コンポーネント
    CMarketAnalyzer* m_analyzer;
    CBuildupDetector* m_detector;
    
    // 設定パラメータ
    struct Settings {
        bool enabled;                   // プラグイン有効/無効
        int minBreakoutBars;           // ブレイクアウト最小バー数
        int maxPullbackBars;           // プルバック最大バー数
        double pullbackMinRatio;       // プルバック最小比率（0.382）
        double pullbackMaxRatio;       // プルバック最大比率（0.786）
        double breakoutMinPips;        // ブレイクアウト最小pips
        double pullbackZonePips;       // プルバックゾーン幅
        int confirmationBars;          // 確認バー数
        double minBreakoutStrength;    // 最小ブレイクアウト強度
        bool requireEMASupport;        // 25EMAサポート必須
        double maxEMADistance;         // 最大EMA距離
    } m_settings;
    
    // 状態管理
    struct BreakoutState {
        bool isActive;                 // ブレイクアウト発生中
        int direction;                 // 方向（1:上, -1:下）
        double breakoutLevel;          // ブレイクアウトレベル
        double breakoutHigh;           // ブレイクアウト後の高値
        double breakoutLow;            // ブレイクアウト後の安値
        datetime breakoutTime;         // ブレイクアウト時刻
        int barsAfterBreakout;        // ブレイクアウト後のバー数
        BuildupInfo originalBuildup;   // 元のビルドアップ
    } m_breakoutState;
    
    struct PullbackState {
        bool isActive;                 // プルバック発生中
        double pullbackLevel;          // プルバックレベル
        double supportZoneHigh;        // サポートゾーン上限
        double supportZoneLow;         // サポートゾーン下限
        int pullbackBars;              // プルバックバー数
        double pullbackRatio;          // プルバック比率
        bool touchedSupport;           // サポートタッチ済み
        bool isReversal;               // 反転確認済み
    } m_pullbackState;
    
    // 内部変数
    datetime m_lastSignalTime;
    int m_cooldownBars;
    
public:
    //+------------------------------------------------------------------+
    //| コンストラクタ                                                   |
    //+------------------------------------------------------------------+
    CPBPullbackPlugin() {
        m_analyzer = NULL;
        m_detector = NULL;
        InitializeSettings();
        ResetStates();
    }
    
    //+------------------------------------------------------------------+
    //| デストラクタ                                                     |
    //+------------------------------------------------------------------+
    ~CPBPullbackPlugin() {
        if(m_analyzer != NULL) delete m_analyzer;
        if(m_detector != NULL) delete m_detector;
    }
    
    //+------------------------------------------------------------------+
    //| 初期化                                                           |
    //+------------------------------------------------------------------+
    bool Initialize(bool enabled = true,
                   int minBreakoutBars = 3,
                   int maxPullbackBars = 10,
                   double pullbackMinRatio = 0.382,
                   double pullbackMaxRatio = 0.786,
                   double breakoutMinPips = 3.0,
                   double pullbackZonePips = 2.0,
                   int confirmationBars = 2,
                   double minBreakoutStrength = 50.0,
                   bool requireEMASupport = true,
                   double maxEMADistance = 15.0) {
        
        // 設定更新
        m_settings.enabled = enabled;
        m_settings.minBreakoutBars = minBreakoutBars;
        m_settings.maxPullbackBars = maxPullbackBars;
        m_settings.pullbackMinRatio = pullbackMinRatio;
        m_settings.pullbackMaxRatio = pullbackMaxRatio;
        m_settings.breakoutMinPips = breakoutMinPips;
        m_settings.pullbackZonePips = pullbackZonePips;
        m_settings.confirmationBars = confirmationBars;
        m_settings.minBreakoutStrength = minBreakoutStrength;
        m_settings.requireEMASupport = requireEMASupport;
        m_settings.maxEMADistance = maxEMADistance;
        
        // コンポーネント初期化
        if(m_analyzer == NULL) m_analyzer = new CMarketAnalyzer();
        if(m_detector == NULL) m_detector = new CBuildupDetector();
        
        if(!m_analyzer.Initialize()) return false;
        if(!m_detector.Initialize()) return false;
        
        Print("PBPullbackPlugin initialized successfully");
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
        
        // ブレイクアウト追跡
        if(!m_breakoutState.isActive) {
            DetectBreakout();
        } else {
            TrackBreakout();
        }
        
        // プルバック追跡
        if(m_breakoutState.isActive && !m_pullbackState.isActive) {
            DetectPullback();
        } else if(m_pullbackState.isActive) {
            TrackPullback();
        }
    }
    
    //+------------------------------------------------------------------+
    //| シグナル取得                                                     |
    //+------------------------------------------------------------------+
    bool GetSignal(SignalInfo &signal) {
        if(!m_settings.enabled) return false;
        
        // プルバック完了後の反転シグナル
        if(m_pullbackState.isActive && m_pullbackState.isReversal) {
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
        
        string prefix = "PBPullback_";
        
        // ブレイクアウトレベル描画
        if(m_breakoutState.isActive) {
            ObjectCreate(0, prefix + "BreakoutLevel", OBJ_HLINE, 0, 0, m_breakoutState.breakoutLevel);
            ObjectSetInteger(0, prefix + "BreakoutLevel", OBJPROP_COLOR, clrBlue);
            ObjectSetInteger(0, prefix + "BreakoutLevel", OBJPROP_WIDTH, 2);
            ObjectSetInteger(0, prefix + "BreakoutLevel", OBJPROP_STYLE, STYLE_DASH);
            
            // ブレイクアウトゾーン
            if(m_breakoutState.direction > 0) {
                ObjectCreate(0, prefix + "BreakoutZone", OBJ_RECTANGLE, 0,
                           m_breakoutState.breakoutTime, m_breakoutState.breakoutLevel,
                           TimeCurrent(), m_breakoutState.breakoutHigh);
                ObjectSetInteger(0, prefix + "BreakoutZone", OBJPROP_COLOR, clrLightBlue);
                ObjectSetInteger(0, prefix + "BreakoutZone", OBJPROP_BACK, true);
            } else {
                ObjectCreate(0, prefix + "BreakoutZone", OBJ_RECTANGLE, 0,
                           m_breakoutState.breakoutTime, m_breakoutState.breakoutLevel,
                           TimeCurrent(), m_breakoutState.breakoutLow);
                ObjectSetInteger(0, prefix + "BreakoutZone", OBJPROP_COLOR, clrLightPink);
                ObjectSetInteger(0, prefix + "BreakoutZone", OBJPROP_BACK, true);
            }
        }
        
        // プルバックゾーン描画
        if(m_pullbackState.isActive) {
            ObjectCreate(0, prefix + "PullbackZone", OBJ_RECTANGLE, 0,
                       TimeCurrent() - 600 * m_pullbackState.pullbackBars,
                       m_pullbackState.supportZoneHigh,
                       TimeCurrent(), m_pullbackState.supportZoneLow);
            ObjectSetInteger(0, prefix + "PullbackZone", OBJPROP_COLOR, clrGreen);
            ObjectSetInteger(0, prefix + "PullbackZone", OBJPROP_BACK, true);
            
            // フィボナッチレベル
            string fibLevels[] = {"38.2%", "50.0%", "61.8%", "78.6%"};
            double fibRatios[] = {0.382, 0.500, 0.618, 0.786};
            
            for(int i = 0; i < 4; i++) {
                double level = CalculateFibLevel(fibRatios[i]);
                ObjectCreate(0, prefix + "Fib_" + fibLevels[i], OBJ_HLINE, 0, 0, level);
                ObjectSetInteger(0, prefix + "Fib_" + fibLevels[i], OBJPROP_COLOR, clrGray);
                ObjectSetInteger(0, prefix + "Fib_" + fibLevels[i], OBJPROP_STYLE, STYLE_DOT);
                
                ObjectCreate(0, prefix + "FibText_" + fibLevels[i], OBJ_TEXT, 0,
                           TimeCurrent() + 300, level);
                ObjectSetString(0, prefix + "FibText_" + fibLevels[i], OBJPROP_TEXT, fibLevels[i]);
                ObjectSetInteger(0, prefix + "FibText_" + fibLevels[i], OBJPROP_COLOR, clrGray);
            }
        }
    }
    
    //+------------------------------------------------------------------+
    //| クリーンアップ                                                   |
    //+------------------------------------------------------------------+
    void CleanupVisualization() {
        string prefix = "PBPullback_";
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
        m_settings.minBreakoutBars = 3;
        m_settings.maxPullbackBars = 10;
        m_settings.pullbackMinRatio = 0.382;
        m_settings.pullbackMaxRatio = 0.786;
        m_settings.breakoutMinPips = 3.0;
        m_settings.pullbackZonePips = 2.0;
        m_settings.confirmationBars = 2;
        m_settings.minBreakoutStrength = 50.0;
        m_settings.requireEMASupport = true;
        m_settings.maxEMADistance = 15.0;
        
        m_lastSignalTime = 0;
        m_cooldownBars = 0;
    }
    
    //+------------------------------------------------------------------+
    //| 状態リセット                                                     |
    //+------------------------------------------------------------------+
    void ResetStates() {
        m_breakoutState.isActive = false;
        m_breakoutState.direction = 0;
        m_breakoutState.breakoutLevel = 0;
        m_breakoutState.breakoutHigh = 0;
        m_breakoutState.breakoutLow = 0;
        m_breakoutState.breakoutTime = 0;
        m_breakoutState.barsAfterBreakout = 0;
        
        m_pullbackState.isActive = false;
        m_pullbackState.pullbackLevel = 0;
        m_pullbackState.supportZoneHigh = 0;
        m_pullbackState.supportZoneLow = 0;
        m_pullbackState.pullbackBars = 0;
        m_pullbackState.pullbackRatio = 0;
        m_pullbackState.touchedSupport = false;
        m_pullbackState.isReversal = false;
    }
    
    //+------------------------------------------------------------------+
    //| ブレイクアウト検出                                               |
    //+------------------------------------------------------------------+
    void DetectBreakout() {
        // ビルドアップ検出
        if(!m_detector.DetectBuildup()) return;
        
        BuildupInfo buildup = m_detector.GetLastBuildup();
        if(!buildup.isValid) return;
        
        double currentPrice = iClose(NULL, 0, 0);
        double breakoutPips = PipsToPrice(m_settings.breakoutMinPips);
        
        // 上方ブレイクアウト
        if(currentPrice > buildup.rangeHigh + breakoutPips) {
            // ブレイクアウト強度チェック
            double strength = CalculateBreakoutStrength(1, buildup);
            if(strength < m_settings.minBreakoutStrength) return;
            
            // ブレイクアウト状態設定
            m_breakoutState.isActive = true;
            m_breakoutState.direction = 1;
            m_breakoutState.breakoutLevel = buildup.rangeHigh;
            m_breakoutState.breakoutHigh = currentPrice;
            m_breakoutState.breakoutLow = buildup.rangeHigh;
            m_breakoutState.breakoutTime = TimeCurrent();
            m_breakoutState.barsAfterBreakout = 0;
            m_breakoutState.originalBuildup = buildup;
            
            Print("Bullish breakout detected at ", currentPrice,
                  " above ", buildup.rangeHigh, " (strength: ", strength, ")");
        }
        // 下方ブレイクアウト
        else if(currentPrice < buildup.rangeLow - breakoutPips) {
            // ブレイクアウト強度チェック
            double strength = CalculateBreakoutStrength(-1, buildup);
            if(strength < m_settings.minBreakoutStrength) return;
            
            // ブレイクアウト状態設定
            m_breakoutState.isActive = true;
            m_breakoutState.direction = -1;
            m_breakoutState.breakoutLevel = buildup.rangeLow;
            m_breakoutState.breakoutHigh = buildup.rangeLow;
            m_breakoutState.breakoutLow = currentPrice;
            m_breakoutState.breakoutTime = TimeCurrent();
            m_breakoutState.barsAfterBreakout = 0;
            m_breakoutState.originalBuildup = buildup;
            
            Print("Bearish breakout detected at ", currentPrice,
                  " below ", buildup.rangeLow, " (strength: ", strength, ")");
        }
    }
    
    //+------------------------------------------------------------------+
    //| ブレイクアウト追跡                                               |
    //+------------------------------------------------------------------+
    void TrackBreakout() {
        m_breakoutState.barsAfterBreakout++;
        
        // タイムアウトチェック（20バー以上経過）
        if(m_breakoutState.barsAfterBreakout > 20) {
            Print("Breakout timeout - resetting states");
            ResetStates();
            return;
        }
        
        double currentHigh = iHigh(NULL, 0, 0);
        double currentLow = iLow(NULL, 0, 0);
        
        // ブレイクアウト範囲更新
        if(m_breakoutState.direction > 0) {
            m_breakoutState.breakoutHigh = MathMax(m_breakoutState.breakoutHigh, currentHigh);
        } else {
            m_breakoutState.breakoutLow = MathMin(m_breakoutState.breakoutLow, currentLow);
        }
        
        // ブレイクアウト失敗チェック
        if(m_breakoutState.direction > 0 && currentLow < m_breakoutState.breakoutLevel) {
            Print("Bullish breakout failed - price back below breakout level");
            ResetStates();
        } else if(m_breakoutState.direction < 0 && currentHigh > m_breakoutState.breakoutLevel) {
            Print("Bearish breakout failed - price back above breakout level");
            ResetStates();
        }
    }
    
    //+------------------------------------------------------------------+
    //| プルバック検出                                                   |
    //+------------------------------------------------------------------+
    void DetectPullback() {
        if(m_breakoutState.barsAfterBreakout < m_settings.minBreakoutBars) return;
        
        double currentPrice = iClose(NULL, 0, 0);
        double breakoutMove = 0;
        double pullbackDistance = 0;
        
        // 上昇ブレイクアウトのプルバック
        if(m_breakoutState.direction > 0) {
            breakoutMove = m_breakoutState.breakoutHigh - m_breakoutState.breakoutLevel;
            pullbackDistance = m_breakoutState.breakoutHigh - currentPrice;
            
            if(pullbackDistance > breakoutMove * m_settings.pullbackMinRatio) {
                // プルバック開始
                m_pullbackState.isActive = true;
                m_pullbackState.pullbackLevel = currentPrice;
                m_pullbackState.supportZoneHigh = m_breakoutState.breakoutLevel + 
                                                 PipsToPrice(m_settings.pullbackZonePips);
                m_pullbackState.supportZoneLow = m_breakoutState.breakoutLevel - 
                                                PipsToPrice(m_settings.pullbackZonePips);
                m_pullbackState.pullbackBars = 0;
                m_pullbackState.pullbackRatio = pullbackDistance / breakoutMove;
                m_pullbackState.touchedSupport = false;
                m_pullbackState.isReversal = false;
                
                Print("Bullish pullback detected - ratio: ", m_pullbackState.pullbackRatio);
            }
        }
        // 下降ブレイクアウトのプルバック
        else if(m_breakoutState.direction < 0) {
            breakoutMove = m_breakoutState.breakoutLevel - m_breakoutState.breakoutLow;
            pullbackDistance = currentPrice - m_breakoutState.breakoutLow;
            
            if(pullbackDistance > breakoutMove * m_settings.pullbackMinRatio) {
                // プルバック開始
                m_pullbackState.isActive = true;
                m_pullbackState.pullbackLevel = currentPrice;
                m_pullbackState.supportZoneHigh = m_breakoutState.breakoutLevel + 
                                                 PipsToPrice(m_settings.pullbackZonePips);
                m_pullbackState.supportZoneLow = m_breakoutState.breakoutLevel - 
                                                PipsToPrice(m_settings.pullbackZonePips);
                m_pullbackState.pullbackBars = 0;
                m_pullbackState.pullbackRatio = pullbackDistance / breakoutMove;
                m_pullbackState.touchedSupport = false;
                m_pullbackState.isReversal = false;
                
                Print("Bearish pullback detected - ratio: ", m_pullbackState.pullbackRatio);
            }
        }
    }
    
    //+------------------------------------------------------------------+
    //| プルバック追跡                                                   |
    //+------------------------------------------------------------------+
    void TrackPullback() {
        m_pullbackState.pullbackBars++;
        
        // タイムアウトチェック
        if(m_pullbackState.pullbackBars > m_settings.maxPullbackBars) {
            Print("Pullback timeout - resetting states");
            ResetStates();
            return;
        }
        
        double currentHigh = iHigh(NULL, 0, 0);
        double currentLow = iLow(NULL, 0, 0);
        double currentClose = iClose(NULL, 0, 0);
        
        // サポートゾーンタッチ確認
        if(!m_pullbackState.touchedSupport) {
            if(currentLow <= m_pullbackState.supportZoneHigh && 
               currentHigh >= m_pullbackState.supportZoneLow) {
                m_pullbackState.touchedSupport = true;
                Print("Support zone touched");
            }
        }
        
        // 反転確認
        if(m_pullbackState.touchedSupport && !m_pullbackState.isReversal) {
            if(CheckReversal()) {
                m_pullbackState.isReversal = true;
                Print("Pullback reversal confirmed");
            }
        }
        
        // プルバック失敗チェック（深すぎるプルバック）
        double breakoutMove = 0;
        double currentPullback = 0;
        
        if(m_breakoutState.direction > 0) {
            breakoutMove = m_breakoutState.breakoutHigh - m_breakoutState.breakoutLevel;
            currentPullback = m_breakoutState.breakoutHigh - currentLow;
            
            if(currentPullback > breakoutMove * m_settings.pullbackMaxRatio) {
                Print("Pullback too deep - exceeds max ratio");
                ResetStates();
            }
        } else {
            breakoutMove = m_breakoutState.breakoutLevel - m_breakoutState.breakoutLow;
            currentPullback = currentHigh - m_breakoutState.breakoutLow;
            
            if(currentPullback > breakoutMove * m_settings.pullbackMaxRatio) {
                Print("Pullback too deep - exceeds max ratio");
                ResetStates();
            }
        }
    }
    
    //+------------------------------------------------------------------+
    //| 反転確認                                                         |
    //+------------------------------------------------------------------+
    bool CheckReversal() {
        if(m_settings.confirmationBars <= 0) return true;
        
        // 確認バーパターンチェック
        int confirmCount = 0;
        
        for(int i = 0; i < m_settings.confirmationBars; i++) {
            double close = iClose(NULL, 0, i);
            double open = iOpen(NULL, 0, i);
            
            if(m_breakoutState.direction > 0) {
                // 上昇反転: 陽線確認
                if(close > open) confirmCount++;
            } else {
                // 下降反転: 陰線確認
                if(close < open) confirmCount++;
            }
        }
        
        return confirmCount >= m_settings.confirmationBars;
    }
    
    //+------------------------------------------------------------------+
    //| エントリー検証                                                   |
    //+------------------------------------------------------------------+
    bool ValidateEntry() {
        // EMAサポート確認
        if(m_settings.requireEMASupport) {
            double ema25 = iMA(NULL, 0, 25, 0, MODE_EMA, PRICE_CLOSE, 0);
            double currentPrice = iClose(NULL, 0, 0);
            double distance = MathAbs(currentPrice - ema25);
            
            if(PriceToPips(distance) > m_settings.maxEMADistance) {
                return false;
            }
            
            // トレンド方向確認
            if(m_breakoutState.direction > 0 && currentPrice < ema25) {
                return false;
            } else if(m_breakoutState.direction < 0 && currentPrice > ema25) {
                return false;
            }
        }
        
        // 市場条件確認
        MarketCondition condition = m_analyzer.GetMarketCondition();
        
        // スプレッドチェック
        if(condition.currentSpread > 2.0) return false;
        
        // 時間帯チェック
        if(!m_analyzer.IsOptimalTradingTime()) return false;
        
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| シグナル生成                                                     |
    //+------------------------------------------------------------------+
    void GenerateSignal(SignalInfo &signal) {
        signal.signalType = m_breakoutState.direction;
        signal.setupName = "PB Pullback";
        signal.entryPrice = iClose(NULL, 0, 0);
        
        // ストップロス設定（プルバックの安値/高値の少し外側）
        if(m_breakoutState.direction > 0) {
            double pullbackLow = GetPullbackLow();
            signal.stopLoss = pullbackLow - PipsToPrice(2.0);
            signal.takeProfit = signal.entryPrice + PipsToPrice(20.0);
        } else {
            double pullbackHigh = GetPullbackHigh();
            signal.stopLoss = pullbackHigh + PipsToPrice(2.0);
            signal.takeProfit = signal.entryPrice - PipsToPrice(20.0);
        }
        
        // シグナル強度計算
        signal.signalStrength = CalculateSignalStrength();
        
        // 理由説明
        signal.reason = StringFormat("Pullback to %.1f%% Fib after breakout",
                                   m_pullbackState.pullbackRatio * 100);
        
        signal.generatedTime = TimeCurrent();
        signal.expirationTime = TimeCurrent() + 300; // 5分間有効
        signal.isValid = true;
        
        // 追加情報
        signal.additionalInfo = StringFormat(
            "Breakout: %.5f, Pullback: %.1f%%, Support: %.5f-%.5f",
            m_breakoutState.breakoutLevel,
            m_pullbackState.pullbackRatio * 100,
            m_pullbackState.supportZoneLow,
            m_pullbackState.supportZoneHigh
        );
        
        // クールダウン設定
        m_lastSignalTime = TimeCurrent();
        m_cooldownBars = 6; // 30分クールダウン
        
        // 状態リセット
        ResetStates();
    }
    
    //+------------------------------------------------------------------+
    //| ブレイクアウト強度計算                                           |
    //+------------------------------------------------------------------+
    double CalculateBreakoutStrength(int direction, BuildupInfo &buildup) {
        double strength = 0;
        
        // ボリューム分析
        long avgVolume = 0;
        long breakoutVolume = iVolume(NULL, 0, 0);
        for(int i = 1; i <= 20; i++) {
            avgVolume += iVolume(NULL, 0, i);
        }
        avgVolume /= 20;
        
        if(breakoutVolume > avgVolume * 1.5) strength += 30;
        else if(breakoutVolume > avgVolume * 1.2) strength += 20;
        else strength += 10;
        
        // モメンタム分析
        double momentum = MathAbs(iClose(NULL, 0, 0) - iOpen(NULL, 0, 0));
        double avgRange = 0;
        for(int i = 1; i <= 10; i++) {
            avgRange += iHigh(NULL, 0, i) - iLow(NULL, 0, i);
        }
        avgRange /= 10;
        
        if(momentum > avgRange * 1.5) strength += 30;
        else if(momentum > avgRange) strength += 20;
        else strength += 10;
        
        // ビルドアップ品質
        strength += buildup.quality * 0.4;
        
        return MathMin(100, strength);
    }
    
    //+------------------------------------------------------------------+
    //| シグナル強度計算                                                 |
    //+------------------------------------------------------------------+
    double CalculateSignalStrength() {
        double strength = 50; // 基本スコア
        
        // フィボナッチレベル評価
        if(m_pullbackState.pullbackRatio >= 0.5 && m_pullbackState.pullbackRatio <= 0.618) {
            strength += 20; // ゴールデンゾーン
        } else if(m_pullbackState.pullbackRatio >= 0.382 && m_pullbackState.pullbackRatio <= 0.5) {
            strength += 15;
        } else {
            strength += 10;
        }
        
        // サポートゾーンタッチ精度
        double touchPrecision = GetSupportTouchPrecision();
        strength += touchPrecision * 15;
        
        // トレンド整合性
        MarketCondition condition = m_analyzer.GetMarketCondition();
        if(condition.trendDirection == m_breakoutState.direction) {
            strength += 15;
        }
        
        return MathMin(100, strength);
    }
    
    //+------------------------------------------------------------------+
    //| フィボナッチレベル計算                                           |
    //+------------------------------------------------------------------+
    double CalculateFibLevel(double ratio) {
        if(m_breakoutState.direction > 0) {
            double move = m_breakoutState.breakoutHigh - m_breakoutState.breakoutLevel;
            return m_breakoutState.breakoutHigh - (move * ratio);
        } else {
            double move = m_breakoutState.breakoutLevel - m_breakoutState.breakoutLow;
            return m_breakoutState.breakoutLow + (move * ratio);
        }
    }
    
    //+------------------------------------------------------------------+
    //| プルバック安値取得                                               |
    //+------------------------------------------------------------------+
    double GetPullbackLow() {
        double low = iLow(NULL, 0, 0);
        for(int i = 1; i < m_pullbackState.pullbackBars; i++) {
            low = MathMin(low, iLow(NULL, 0, i));
        }
        return low;
    }
    
    //+------------------------------------------------------------------+
    //| プルバック高値取得                                               |
    //+------------------------------------------------------------------+
    double GetPullbackHigh() {
        double high = iHigh(NULL, 0, 0);
        for(int i = 1; i < m_pullbackState.pullbackBars; i++) {
            high = MathMax(high, iHigh(NULL, 0, i));
        }
        return high;
    }
    
    //+------------------------------------------------------------------+
    //| サポートタッチ精度取得                                           |
    //+------------------------------------------------------------------+
    double GetSupportTouchPrecision() {
        double lowestPrice = GetPullbackLow();
        double highestPrice = GetPullbackHigh();
        double zoneCenter = (m_pullbackState.supportZoneHigh + m_pullbackState.supportZoneLow) / 2;
        
        double touchPrice = (m_breakoutState.direction > 0) ? lowestPrice : highestPrice;
        double distance = MathAbs(touchPrice - zoneCenter);
        double zoneWidth = m_pullbackState.supportZoneHigh - m_pullbackState.supportZoneLow;
        
        if(zoneWidth > 0) {
            return MathMax(0, 1.0 - (distance / zoneWidth));
        }
        return 0.5;
    }
};

//+------------------------------------------------------------------+