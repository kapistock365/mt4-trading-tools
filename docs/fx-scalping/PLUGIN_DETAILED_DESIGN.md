# FX 5分足スキャルピングEA - プラグイン詳細設計書

## 1. パターンブレイクプラグイン詳細

### 1.1 クラス定義
```cpp
class CPatternBreakPlugin : public CPluginBase {
private:
    // === 設定パラメータ ===
    int     m_minBuildupBars;        // 最小ビルドアップバー数 (3)
    int     m_maxBuildupBars;        // 最大ビルドアップバー数 (10)
    double  m_buildupRangePips;      // ビルドアップ最大幅 (10.0)
    double  m_breakoutMinPips;       // ブレイク最小幅 (2.0)
    double  m_breakoutMaxPips;       // ブレイク最大幅 (5.0)
    double  m_maxEMADistance;        // EMAからの最大距離 (15.0)
    int     m_confirmationBars;      // ブレイク確認バー数 (2)
    bool    m_useVolumeFilter;       // ボリュームフィルター使用 (false)
    
    // === 内部状態変数 ===
    double  m_patternHighPrice;      // パターン上限価格
    double  m_patternLowPrice;       // パターン下限価格
    int     m_patternStartBar;       // パターン開始バー
    int     m_patternEndBar;         // パターン終了バー
    int     m_buildupStartBar;       // ビルドアップ開始バー
    int     m_buildupBarCount;       // ビルドアップバー数
    bool    m_isPatternActive;       // パターン有効フラグ
    int     m_lastBreakDirection;    // 最後のブレイク方向
    datetime m_lastBreakTime;        // 最後のブレイク時刻
    double  m_buildupCenterPrice;    // ビルドアップ中心価格
    
    // === キャッシュ変数 ===
    double  m_cached25EMA;           // 25EMAキャッシュ
    double  m_cachedATR;             // ATRキャッシュ
    datetime m_cacheUpdateTime;      // キャッシュ更新時刻
    
public:
    // === コンストラクタ/デストラクタ ===
    CPatternBreakPlugin();
    ~CPatternBreakPlugin();
    
    // === 初期化/終了処理 ===
    virtual bool OnInit() override;
    virtual void OnDeinit() override;
    
    // === メイン処理 ===
    virtual void OnTick() override;
    virtual int GetSignal() override;
    
    // === パターン認識 ===
    bool ScanForPatterns();
    bool IdentifyRangePattern();
    bool IdentifyTrianglePattern();
    bool IdentifyFlagPattern();
    bool IdentifyWedgePattern();
    
    // === ビルドアップ分析 ===
    bool AnalyzeBuildupQuality();
    int CountBuildupBars(int startBar, int endBar);
    double CalculateBuildupRange(int startBar, int endBar);
    double GetBuildupDensity();
    bool IsCompression();
    
    // === ブレイクアウト判定 ===
    int CheckBreakout();
    bool IsValidBreakout(int direction);
    bool CheckFalseBreak();
    bool CheckTeaseBreak();
    double GetBreakoutStrength();
    
    // === フィルター ===
    bool ApplyTimeFilter();
    bool ApplyVolatilityFilter();
    bool ApplyTrendFilter();
    bool ApplyEMAFilter();
    bool ApplyRoundNumberFilter();
    
    // === エントリー/エグジット ===
    virtual bool ValidateEntry() override;
    virtual bool ValidateExit() override;
    double CalculateStopLoss(int direction);
    double CalculateTakeProfit(int direction);
    
    // === ユーティリティ ===
    void UpdateCache();
    void ResetPattern();
    void LogPatternInfo();
    string GetPatternDescription();
};
```

### 1.2 詳細アルゴリズム

#### パターン認識アルゴリズム
```cpp
bool CPatternBreakPlugin::IdentifyRangePattern() {
    // レンジパターンの認識
    // 1. 過去N本の高値安値を取得
    double highs[], lows[];
    ArrayResize(highs, 20);
    ArrayResize(lows, 20);
    
    for (int i = 0; i < 20; i++) {
        highs[i] = iHigh(NULL, PERIOD_M5, i);
        lows[i] = iLow(NULL, PERIOD_M5, i);
    }
    
    // 2. 高値と安値の標準偏差を計算
    double highStdDev = CalculateStdDev(highs);
    double lowStdDev = CalculateStdDev(lows);
    
    // 3. レンジ判定（標準偏差が小さい）
    if (highStdDev < 2.0 * Point && lowStdDev < 2.0 * Point) {
        // 4. レンジの境界を特定
        m_patternHighPrice = highs[ArrayMaximum(highs)];
        m_patternLowPrice = lows[ArrayMinimum(lows)];
        
        // 5. レンジ幅チェック（5-20pips）
        double rangeSize = (m_patternHighPrice - m_patternLowPrice) / Point / 10;
        if (rangeSize >= 5.0 && rangeSize <= 20.0) {
            m_isPatternActive = true;
            m_patternStartBar = 19;
            m_patternEndBar = 0;
            return true;
        }
    }
    
    return false;
}
```

#### ビルドアップ品質評価
```cpp
bool CPatternBreakPlugin::AnalyzeBuildupQuality() {
    if (!m_isPatternActive) return false;
    
    // 品質スコア計算（0-100）
    double qualityScore = 0;
    
    // 1. バー数評価（理想: 5-7本）
    int barCount = CountBuildupBars(m_buildupStartBar, 0);
    if (barCount >= 5 && barCount <= 7) {
        qualityScore += 30;
    } else if (barCount >= 3 && barCount <= 10) {
        qualityScore += 20;
    }
    
    // 2. 圧縮度評価（値幅が徐々に狭まる）
    double compressionRatio = GetCompressionRatio();
    if (compressionRatio > 0.7) {
        qualityScore += 30;
    } else if (compressionRatio > 0.5) {
        qualityScore += 20;
    }
    
    // 3. 短小線の割合
    double dojiRatio = GetDojiRatio();
    if (dojiRatio > 0.6) {
        qualityScore += 20;
    } else if (dojiRatio > 0.4) {
        qualityScore += 10;
    }
    
    // 4. 位置評価（パターン境界に近い）
    double positionScore = GetPositionScore();
    qualityScore += positionScore * 20;
    
    // 最終判定（60点以上で有効）
    return (qualityScore >= 60);
}
```

### 1.3 状態遷移図
```
[待機状態]
    ↓ パターン検出
[パターン監視中]
    ↓ ビルドアップ形成
[ビルドアップ監視中]
    ↓ ブレイクアウト発生
[ブレイク確認中]
    ↓ 確認完了
[シグナル生成]
    ↓ エントリー実行
[ポジション保有中]
    ↓ エグジット
[待機状態]
```

## 2. プルバックプラグイン詳細

### 2.1 クラス定義
```cpp
class CPBPullbackPlugin : public CPluginBase {
private:
    // === 設定パラメータ ===
    double  m_minPullbackDepth;      // 最小プルバック深さ (30.0%)
    double  m_maxPullbackDepth;      // 最大プルバック深さ (70.0%)
    int     m_maxPullbackBars;       // プルバック最大期間 (15)
    double  m_retestBuffer;          // リテストバッファ (2.0 pips)
    bool    m_requireEMATouch;       // EMAタッチ必須 (true)
    bool    m_useFibonacci;          // フィボナッチ使用 (true)
    
    // === ブレイク追跡変数 ===
    struct BreakoutInfo {
        datetime time;                // ブレイク時刻
        double price;                 // ブレイク価格
        int direction;                // ブレイク方向
        double breakLevel;            // ブレイクレベル
        double swingHigh;             // スイング高値
        double swingLow;              // スイング安値
        bool isValid;                 // 有効フラグ
    };
    BreakoutInfo m_lastBreakout;
    
    // === プルバック状態 ===
    enum PullbackState {
        STATE_NO_BREAKOUT,            // ブレイクなし
        STATE_BREAKOUT_DETECTED,      // ブレイク検出
        STATE_PULLBACK_IN_PROGRESS,   // プルバック中
        STATE_PULLBACK_COMPLETE,      // プルバック完了
        STATE_REVERSAL_CONFIRMED       // 反転確認
    };
    PullbackState m_currentState;
    
    // === プルバック測定 ===
    double  m_pullbackExtreme;       // プルバック極値
    int     m_pullbackBars;          // プルバック期間
    double  m_pullbackDepth;         // プルバック深さ
    
public:
    // === メイン処理 ===
    virtual int GetSignal() override;
    
    // === ブレイク検出・追跡 ===
    bool DetectInitialBreakout();
    void TrackBreakoutProgress();
    bool IsBreakoutStillValid();
    
    // === プルバック分析 ===
    bool AnalyzePullback();
    double CalculatePullbackDepth();
    bool IsPullbackWithinRange();
    bool HasReachedKeyLevel();
    
    // === 反転確認 ===
    bool ConfirmReversal();
    bool CheckPinBar();
    bool CheckEngulfingPattern();
    bool CheckInsideBarBreak();
    bool CheckMomentumShift();
    
    // === フィボナッチ分析 ===
    double GetFibonacciLevel(double ratio);
    bool IsNearFibLevel(double price, double tolerance);
    double GetOptimalFibEntry();
    
    // === リスク管理 ===
    double CalculatePullbackStopLoss();
    double CalculatePullbackTarget();
};
```

### 2.2 プルバック検出アルゴリズム
```cpp
bool CPBPullbackPlugin::AnalyzePullback() {
    if (m_currentState != STATE_BREAKOUT_DETECTED) return false;
    
    // 1. プルバックの進行状況を測定
    double currentPrice = (m_lastBreakout.direction > 0) ? 
                          iLow(NULL, PERIOD_M5, 0) : 
                          iHigh(NULL, PERIOD_M5, 0);
    
    // 2. プルバック深さを計算
    double swingRange = m_lastBreakout.swingHigh - m_lastBreakout.swingLow;
    double pullbackDistance = MathAbs(currentPrice - m_lastBreakout.price);
    m_pullbackDepth = (pullbackDistance / swingRange) * 100;
    
    // 3. プルバック範囲チェック
    if (m_pullbackDepth >= m_minPullbackDepth && 
        m_pullbackDepth <= m_maxPullbackDepth) {
        
        // 4. キーレベルチェック
        bool keyLevelReached = false;
        
        // a. ブレイクレベルのリテスト
        if (MathAbs(currentPrice - m_lastBreakout.breakLevel) <= m_retestBuffer * Point * 10) {
            keyLevelReached = true;
        }
        
        // b. 25EMAタッチ
        if (m_requireEMATouch) {
            double ema25 = iMA(NULL, PERIOD_M5, 25, 0, MODE_EMA, PRICE_CLOSE, 0);
            if (MathAbs(currentPrice - ema25) <= 3.0 * Point * 10) {
                keyLevelReached = true;
            }
        }
        
        // c. フィボナッチレベル
        if (m_useFibonacci) {
            double fib382 = GetFibonacciLevel(0.382);
            double fib500 = GetFibonacciLevel(0.500);
            double fib618 = GetFibonacciLevel(0.618);
            
            if (IsNearFibLevel(currentPrice, 2.0)) {
                keyLevelReached = true;
            }
        }
        
        if (keyLevelReached) {
            m_currentState = STATE_PULLBACK_COMPLETE;
            m_pullbackExtreme = currentPrice;
            return true;
        }
    }
    
    // 5. タイムアウトチェック
    m_pullbackBars++;
    if (m_pullbackBars > m_maxPullbackBars) {
        // プルバックが長すぎる - リセット
        m_currentState = STATE_NO_BREAKOUT;
        return false;
    }
    
    return false;
}
```

## 3. コンビプラグイン詳細

### 3.1 クラス定義
```cpp
class CPBComboPlugin : public CPluginBase {
private:
    // === 設定パラメータ ===
    int     m_minComboFactors;       // 最小複合要因数 (2)
    double  m_comboScoreThreshold;   // 複合スコア閾値 (70.0)
    bool    m_requireAllFactors;     // 全要因必須 (false)
    
    // === 複合要因 ===
    struct ComboFactor {
        string name;                  // 要因名
        double weight;                // 重み（0-1.0）
        bool isPresent;               // 存在フラグ
        double score;                 // スコア（0-100）
        datetime lastCheck;           // 最終チェック時刻
    };
    
    ComboFactor m_factors[];
    
    // === 複合パターン ===
    enum ComboPattern {
        COMBO_NONE,
        COMBO_FAILED_BREAK_REVERSAL,  // 失敗ブレイクからの反転
        COMBO_TRIPLE_SUPPORT,         // トリプルサポート/レジスタンス
        COMBO_TIME_SYNC,              // 時間帯同期
        COMBO_PATTERN_CONFLUENCE,     // パターン合流
        COMBO_MOMENTUM_DIVERGENCE      // モメンタムダイバージェンス
    };
    
    ComboPattern m_detectedPattern;
    double m_comboScore;
    
public:
    // === 初期化 ===
    virtual bool OnInit() override {
        // 複合要因の設定
        ArrayResize(m_factors, 10);
        
        m_factors[0].name = "Pattern Break";
        m_factors[0].weight = 0.3;
        
        m_factors[1].name = "Pullback Complete";
        m_factors[1].weight = 0.25;
        
        m_factors[2].name = "EMA Support";
        m_factors[2].weight = 0.15;
        
        m_factors[3].name = "Round Number";
        m_factors[3].weight = 0.1;
        
        m_factors[4].name = "Time Zone";
        m_factors[4].weight = 0.1;
        
        m_factors[5].name = "Momentum";
        m_factors[5].weight = 0.1;
        
        return true;
    }
    
    // === シグナル生成 ===
    virtual int GetSignal() override;
    
    // === 複合要因分析 ===
    void AnalyzeAllFactors();
    bool CheckPatternBreakFactor();
    bool CheckPullbackFactor();
    bool CheckEMAFactor();
    bool CheckRoundNumberFactor();
    bool CheckTimeZoneFactor();
    bool CheckMomentumFactor();
    
    // === 複合パターン検出 ===
    bool DetectFailedBreakReversal();
    bool DetectTripleSupport();
    bool DetectTimeSync();
    bool DetectPatternConfluence();
    
    // === スコア計算 ===
    double CalculateComboScore();
    double GetWeightedScore();
    int CountActiveFactors();
};
```

### 3.2 複合スコア計算アルゴリズム
```cpp
double CPBComboPlugin::CalculateComboScore() {
    double totalScore = 0;
    double totalWeight = 0;
    int activeFactors = 0;
    
    // 1. 各要因のスコアを集計
    for (int i = 0; i < ArraySize(m_factors); i++) {
        if (m_factors[i].isPresent) {
            totalScore += m_factors[i].score * m_factors[i].weight;
            totalWeight += m_factors[i].weight;
            activeFactors++;
        }
    }
    
    // 2. 基本スコア計算
    double baseScore = (totalWeight > 0) ? (totalScore / totalWeight) : 0;
    
    // 3. ボーナス/ペナルティ適用
    double finalScore = baseScore;
    
    // a. 複数要因ボーナス
    if (activeFactors >= 3) {
        finalScore += 10;  // 3要因以上で+10
    }
    if (activeFactors >= 4) {
        finalScore += 10;  // 4要因以上で追加+10
    }
    
    // b. 特定組み合わせボーナス
    if (m_factors[0].isPresent && m_factors[1].isPresent) {
        // パターンブレイク + プルバック完了
        finalScore += 15;
    }
    
    if (m_factors[2].isPresent && m_factors[3].isPresent) {
        // EMAサポート + ラウンドナンバー
        finalScore += 10;
    }
    
    // c. 時間帯ボーナス
    if (m_factors[4].isPresent && m_factors[4].score > 80) {
        // 最適時間帯（ロンドン/NYオープン）
        finalScore *= 1.2;
    }
    
    // 4. スコア正規化（0-100）
    finalScore = MathMin(100, MathMax(0, finalScore));
    
    m_comboScore = finalScore;
    return finalScore;
}
```

## 4. 補助プラグイン詳細

### 4.1 TimeFilterPlugin（時間フィルター）
```cpp
class CTimeFilterPlugin : public CPluginBase {
private:
    // === 取引時間帯設定 ===
    struct TradingSession {
        string name;                  // セッション名
        int startHour;                // 開始時（サーバー時間）
        int startMinute;              
        int endHour;                  // 終了時
        int endMinute;
        bool enabled;                 // 有効フラグ
        double volatilityMultiplier;  // ボラティリティ係数
    };
    
    TradingSession m_sessions[];
    
public:
    virtual bool OnInit() override {
        ArrayResize(m_sessions, 4);
        
        // 東京セッション（低ボラティリティ）
        m_sessions[0].name = "Tokyo";
        m_sessions[0].startHour = 0;
        m_sessions[0].startMinute = 0;
        m_sessions[0].endHour = 9;
        m_sessions[0].endMinute = 0;
        m_sessions[0].enabled = false;  // デフォルト無効
        m_sessions[0].volatilityMultiplier = 0.7;
        
        // ロンドンセッション（高ボラティリティ）
        m_sessions[1].name = "London";
        m_sessions[1].startHour = 7;   // GMT時間調整必要
        m_sessions[1].startMinute = 0;
        m_sessions[1].endHour = 16;
        m_sessions[1].endMinute = 0;
        m_sessions[1].enabled = true;
        m_sessions[1].volatilityMultiplier = 1.2;
        
        // NYセッション（高ボラティリティ）
        m_sessions[2].name = "NewYork";
        m_sessions[2].startHour = 12;
        m_sessions[2].startMinute = 0;
        m_sessions[2].endHour = 21;
        m_sessions[2].endMinute = 0;
        m_sessions[2].enabled = true;
        m_sessions[2].volatilityMultiplier = 1.3;
        
        // オーバーラップ（最高ボラティリティ）
        m_sessions[3].name = "Overlap";
        m_sessions[3].startHour = 12;
        m_sessions[3].startMinute = 0;
        m_sessions[3].endHour = 16;
        m_sessions[3].endMinute = 0;
        m_sessions[3].enabled = true;
        m_sessions[3].volatilityMultiplier = 1.5;
        
        return true;
    }
    
    bool IsGoodTradingTime() {
        datetime currentTime = TimeCurrent();
        int hour = TimeHour(currentTime);
        int minute = TimeMinute(currentTime);
        
        for (int i = 0; i < ArraySize(m_sessions); i++) {
            if (!m_sessions[i].enabled) continue;
            
            if (IsTimeInSession(hour, minute, m_sessions[i])) {
                return true;
            }
        }
        
        return false;
    }
    
    double GetVolatilityMultiplier() {
        // 現在のセッションのボラティリティ係数を返す
        // ロット調整やTP/SL調整に使用
    }
};
```

### 4.2 SpreadFilterPlugin（スプレッドフィルター）
```cpp
class CSpreadFilterPlugin : public CPluginBase {
private:
    double m_maxSpreadPips;          // 最大スプレッド
    double m_avgSpreadPips;          // 平均スプレッド
    int    m_spreadHistory[];        // スプレッド履歴
    int    m_historySize;            // 履歴サイズ
    
public:
    bool IsSpreadAcceptable() {
        double currentSpread = MarketInfo(Symbol(), MODE_SPREAD) / 10.0;
        
        // 1. 絶対値チェック
        if (currentSpread > m_maxSpreadPips) {
            return false;
        }
        
        // 2. 相対値チェック（平均の150%以下）
        UpdateSpreadHistory(currentSpread);
        double avgSpread = CalculateAverageSpread();
        
        if (currentSpread > avgSpread * 1.5) {
            return false;
        }
        
        // 3. 急激な拡大チェック
        if (IsSpreadExpanding()) {
            return false;
        }
        
        return true;
    }
    
    void AdjustTargetsForSpread(double &tp, double &sl) {
        double currentSpread = MarketInfo(Symbol(), MODE_SPREAD) / 10.0;
        
        // スプレッド分だけTP/SLを調整
        tp += currentSpread;
        // SLは調整しない（リスク固定）
    }
};
```

## 5. プラグイン統合管理

### 5.1 プラグインマネージャー
```cpp
class CPluginManager {
private:
    CPluginBase* m_plugins[];         // プラグイン配列
    int m_pluginCount;                // プラグイン数
    int m_activePlugin;               // アクティブプラグイン
    
public:
    void RegisterPlugin(CPluginBase* plugin) {
        // プラグインを登録
        int size = ArraySize(m_plugins);
        ArrayResize(m_plugins, size + 1);
        m_plugins[size] = plugin;
        m_pluginCount++;
    }
    
    int GetCombinedSignal() {
        int strongestSignal = 0;
        double highestScore = 0;
        
        // 全プラグインからシグナルを収集
        for (int i = 0; i < m_pluginCount; i++) {
            if (!m_plugins[i].IsEnabled()) continue;
            
            int signal = m_plugins[i].GetSignal();
            if (signal != 0) {
                double score = m_plugins[i].GetSignalStrength();
                
                if (score > highestScore) {
                    strongestSignal = signal;
                    highestScore = score;
                    m_activePlugin = i;
                }
            }
        }
        
        return strongestSignal;
    }
    
    void OnTick() {
        // 全プラグインのOnTickを呼び出し
        for (int i = 0; i < m_pluginCount; i++) {
            if (m_plugins[i].IsEnabled()) {
                m_plugins[i].OnTick();
            }
        }
    }
};
```

## 6. プラグイン間通信

### 6.1 イベントシステム
```cpp
enum PluginEvent {
    EVENT_PATTERN_DETECTED,
    EVENT_BUILDUP_FORMED,
    EVENT_BREAKOUT_OCCURRED,
    EVENT_PULLBACK_STARTED,
    EVENT_REVERSAL_CONFIRMED,
    EVENT_POSITION_OPENED,
    EVENT_POSITION_CLOSED
};

class CEventBus {
private:
    struct EventHandler {
        CPluginBase* plugin;
        PluginEvent event;
    };
    EventHandler m_handlers[];
    
public:
    void Subscribe(CPluginBase* plugin, PluginEvent event) {
        // イベント購読登録
    }
    
    void Publish(PluginEvent event, string data) {
        // イベント発行
        for (int i = 0; i < ArraySize(m_handlers); i++) {
            if (m_handlers[i].event == event) {
                m_handlers[i].plugin.OnEvent(event, data);
            }
        }
    }
};
```

### 6.2 共有データストア
```cpp
class CSharedDataStore {
private:
    // 共有データ構造
    struct MarketContext {
        int trend;
        double trendStrength;
        double volatility;
        double support;
        double resistance;
        datetime lastUpdate;
    };
    
    MarketContext m_context;
    
public:
    void UpdateContext(string key, double value) {
        // コンテキスト更新
    }
    
    double GetContext(string key) {
        // コンテキスト取得
    }
    
    bool IsContextFresh(int maxAge) {
        // データ鮮度チェック
        return (TimeCurrent() - m_context.lastUpdate) < maxAge;
    }
};
```

## 7. パフォーマンス最適化

### 7.1 計算キャッシング
```cpp
class CCalculationCache {
private:
    struct CacheEntry {
        string key;
        double value;
        datetime timestamp;
        int ttl;  // Time to live (seconds)
    };
    CacheEntry m_cache[];
    
public:
    double GetCached(string key, double defaultValue) {
        for (int i = 0; i < ArraySize(m_cache); i++) {
            if (m_cache[i].key == key) {
                if (TimeCurrent() - m_cache[i].timestamp < m_cache[i].ttl) {
                    return m_cache[i].value;
                }
            }
        }
        return defaultValue;
    }
    
    void SetCache(string key, double value, int ttl = 60) {
        // キャッシュ設定
    }
};
```

### 7.2 処理優先度管理
```cpp
class CPriorityManager {
public:
    void SetPluginPriority(CPluginBase* plugin, int priority) {
        plugin.SetPriority(priority);
    }
    
    void OptimizeProcessing() {
        // 優先度に基づく処理順序最適化
        // 高優先度プラグインを先に処理
        // 低優先度プラグインはスキップ可能
    }
};
```

---
*作成日: 2025-08-25*
*バージョン: 1.0*