//+------------------------------------------------------------------+
//|                                     FX5MinScalpingIndicator.mq4 |
//|                                    FX 5分足スキャルピング インジケーター |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property link      ""
#property version   "1.00"
#property strict

#property indicator_chart_window
#property indicator_buffers 0

// インクルード（既存のロジックを流用）
#include <FX5MinScalping/DataStructures.mqh>
#include <FX5MinScalping/MarketAnalyzer.mqh>
#include <FX5MinScalping/BuildupDetector.mqh>

// === パラメータ設定 ===
// ビルドアップ検出
input int       MinBuildupBars      = 3;                  // 最小ビルドアップバー数
input int       MaxBuildupBars      = 10;                 // 最大ビルドアップバー数
input double    BuildupRangePips    = 10.0;               // ビルドアップ最大幅（pips）

// ブレイクアウト設定
input double    BreakoutMinPips     = 0.5;                // ブレイク最小幅（pips）
input double    BreakoutMaxPips     = 5.0;                // ブレイク最大幅（pips）

// トレード設定
input double    StopLossPips        = 10.0;               // 損切り（pips）
input double    TakeProfitPips      = 20.0;               // 利確（pips）
input double    RiskPercent         = 2.0;                // リスク率（%）

// 表示設定
input color     RangeColor           = clrGray;           // レンジ色
input color     BuildupColor         = clrYellow;         // ビルドアップ色
input color     BuySignalColor       = clrBlue;           // 買いシグナル色
input color     SellSignalColor      = clrRed;            // 売りシグナル色
input bool      ShowInfoPanel        = true;              // 情報パネル表示
input bool      EnableAlerts         = true;              // アラート有効
input int       AlertDistancePips    = 2;                 // アラート発動距離（pips）

// グローバル変数
CMarketAnalyzer* g_marketAnalyzer;
CBuildupDetector* g_buildupDetector;
PatternInfo g_currentPattern;
BuildupInfo g_currentBuildup;
bool g_patternActive = false;
datetime g_lastAlertTime = 0;
int g_alertCooldown = 300; // 5分間のクールダウン

// 描画用定数
const string PREFIX = "FX5M_";
const int FONT_SIZE = 9;
const string FONT_NAME = "Arial";

//+------------------------------------------------------------------+
//| インジケーター初期化                                              |
//+------------------------------------------------------------------+
int OnInit() {
    // オブジェクトクリア
    ObjectsDeleteAll(0, PREFIX);
    
    // アナライザー初期化
    g_marketAnalyzer = new CMarketAnalyzer();
    if(!g_marketAnalyzer.Initialize(Symbol(), PERIOD_M5)) {
        Print("Failed to initialize MarketAnalyzer");
        return INIT_FAILED;
    }
    
    // ビルドアップ検出器初期化
    g_buildupDetector = new CBuildupDetector();
    if(!g_buildupDetector.Initialize(MinBuildupBars, MaxBuildupBars, BuildupRangePips)) {
        Print("Failed to initialize BuildupDetector");
        return INIT_FAILED;
    }
    
    // 情報パネル初期化
    if(ShowInfoPanel) {
        CreateInfoPanel();
    }
    
    Print("=== FX 5-Minute Scalping Indicator Initialized ===");
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| インジケーター終了処理                                            |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    // オブジェクト削除
    ObjectsDeleteAll(0, PREFIX);
    
    // メモリ解放
    if(g_marketAnalyzer != NULL) {
        delete g_marketAnalyzer;
        g_marketAnalyzer = NULL;
    }
    
    if(g_buildupDetector != NULL) {
        delete g_buildupDetector;
        g_buildupDetector = NULL;
    }
    
    Print("=== FX 5-Minute Scalping Indicator Deinitialized ===");
}

//+------------------------------------------------------------------+
//| インジケーター計算                                                |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[]) {
    
    // 十分なバーがない場合は終了
    if(rates_total < 100) return rates_total;
    
    // パターン検出（既存ロジックを使用）
    DetectAndDrawPattern();
    
    // 予測ライン描画
    if(g_patternActive) {
        DrawPredictionLines();
        CheckForAlerts();
    }
    
    // 情報パネル更新
    if(ShowInfoPanel) {
        UpdateInfoPanel();
    }
    
    return rates_total;
}

//+------------------------------------------------------------------+
//| パターン検出と描画                                                |
//+------------------------------------------------------------------+
void DetectAndDrawPattern() {
    // 既存のロジックをそのまま使用
    if(g_marketAnalyzer.DetectRangePattern(g_currentPattern)) {
        if(g_buildupDetector.DetectBuildup(0)) {
            g_currentBuildup = g_buildupDetector.GetCurrentBuildup();
            
            // ビルドアップがパターン境界付近にあるか確認
            double distanceToUpper = PriceToPips(g_currentPattern.upperBoundary - g_currentBuildup.centerPrice);
            double distanceToLower = PriceToPips(g_currentBuildup.centerPrice - g_currentPattern.lowerBoundary);
            
            if(distanceToUpper <= 5.0 || distanceToLower <= 5.0) {
                g_patternActive = true;
                
                // レンジボックス描画
                DrawRangeBox();
                
                // ビルドアップゾーン描画
                DrawBuildupZone();
            }
        }
    }
}

//+------------------------------------------------------------------+
//| レンジボックス描画                                                |
//+------------------------------------------------------------------+
void DrawRangeBox() {
    string nameUpper = PREFIX + "RangeUpper";
    string nameLower = PREFIX + "RangeLower";
    string nameBox = PREFIX + "RangeBox";
    
    // 上限ライン
    if(ObjectFind(0, nameUpper) < 0) {
        ObjectCreate(0, nameUpper, OBJ_HLINE, 0, 0, g_currentPattern.upperBoundary);
    }
    ObjectSetDouble(0, nameUpper, OBJPROP_PRICE, g_currentPattern.upperBoundary);
    ObjectSetInteger(0, nameUpper, OBJPROP_COLOR, RangeColor);
    ObjectSetInteger(0, nameUpper, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, nameUpper, OBJPROP_WIDTH, 2);
    
    // 下限ライン
    if(ObjectFind(0, nameLower) < 0) {
        ObjectCreate(0, nameLower, OBJ_HLINE, 0, 0, g_currentPattern.lowerBoundary);
    }
    ObjectSetDouble(0, nameLower, OBJPROP_PRICE, g_currentPattern.lowerBoundary);
    ObjectSetInteger(0, nameLower, OBJPROP_COLOR, RangeColor);
    ObjectSetInteger(0, nameLower, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, nameLower, OBJPROP_WIDTH, 2);
    
    // レンジボックス（背景）
    datetime startTime = iTime(Symbol(), PERIOD_M5, g_currentPattern.startBar);
    datetime endTime = TimeCurrent() + PeriodSeconds(PERIOD_M5) * 10; // 10本先まで表示
    
    if(ObjectFind(0, nameBox) < 0) {
        ObjectCreate(0, nameBox, OBJ_RECTANGLE, 0, startTime, g_currentPattern.upperBoundary, 
                    endTime, g_currentPattern.lowerBoundary);
    }
    ObjectSetInteger(0, nameBox, OBJPROP_COLOR, RangeColor);
    ObjectSetInteger(0, nameBox, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, nameBox, OBJPROP_WIDTH, 1);
    ObjectSetInteger(0, nameBox, OBJPROP_FILL, true);
    ObjectSetInteger(0, nameBox, OBJPROP_BACK, true);
    ObjectSetInteger(0, nameBox, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| ビルドアップゾーン描画                                            |
//+------------------------------------------------------------------+
void DrawBuildupZone() {
    string nameZone = PREFIX + "BuildupZone";
    
    datetime startTime = iTime(Symbol(), PERIOD_M5, g_currentBuildup.endBar);
    datetime endTime = iTime(Symbol(), PERIOD_M5, g_currentBuildup.startBar);
    
    if(ObjectFind(0, nameZone) < 0) {
        ObjectCreate(0, nameZone, OBJ_RECTANGLE, 0, startTime, g_currentBuildup.rangeHigh,
                    endTime, g_currentBuildup.rangeLow);
    }
    ObjectSetInteger(0, nameZone, OBJPROP_COLOR, BuildupColor);
    ObjectSetInteger(0, nameZone, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, nameZone, OBJPROP_WIDTH, 1);
    ObjectSetInteger(0, nameZone, OBJPROP_FILL, true);
    ObjectSetInteger(0, nameZone, OBJPROP_BACK, true);
    ObjectSetInteger(0, nameZone, OBJPROP_SELECTABLE, false);
    
    // ビルドアップラベル
    string nameLabel = PREFIX + "BuildupLabel";
    double labelPrice = g_currentBuildup.centerPrice;
    
    if(ObjectFind(0, nameLabel) < 0) {
        ObjectCreate(0, nameLabel, OBJ_TEXT, 0, endTime, labelPrice);
    }
    ObjectSetString(0, nameLabel, OBJPROP_TEXT, 
                   StringFormat("Buildup: %d bars, %.1f pips (Q:%d%%)", 
                   g_currentBuildup.barCount, g_currentBuildup.rangeSize, g_currentBuildup.quality));
    ObjectSetString(0, nameLabel, OBJPROP_FONT, FONT_NAME);
    ObjectSetInteger(0, nameLabel, OBJPROP_FONTSIZE, FONT_SIZE);
    ObjectSetInteger(0, nameLabel, OBJPROP_COLOR, BuildupColor);
}

//+------------------------------------------------------------------+
//| 予測ライン描画                                                    |
//+------------------------------------------------------------------+
void DrawPredictionLines() {
    // 買いエントリーライン
    double buyEntry = g_currentPattern.upperBoundary + PipsToPrice(BreakoutMinPips);
    DrawPredictionLine("BuyEntry", buyEntry, BuySignalColor, STYLE_DASHDOT,
                      StringFormat("BUY Entry: %.5f", buyEntry));
    
    // 買いSL/TP
    double buySL = buyEntry - PipsToPrice(StopLossPips);
    double buyTP = buyEntry + PipsToPrice(TakeProfitPips);
    DrawPredictionLine("BuySL", buySL, clrIndianRed, STYLE_DOT,
                      StringFormat("BUY SL: %.5f (-%.1f pips)", buySL, StopLossPips));
    DrawPredictionLine("BuyTP", buyTP, clrLimeGreen, STYLE_DOT,
                      StringFormat("BUY TP: %.5f (+%.1f pips)", buyTP, TakeProfitPips));
    
    // 売りエントリーライン
    double sellEntry = g_currentPattern.lowerBoundary - PipsToPrice(BreakoutMinPips);
    DrawPredictionLine("SellEntry", sellEntry, SellSignalColor, STYLE_DASHDOT,
                      StringFormat("SELL Entry: %.5f", sellEntry));
    
    // 売りSL/TP
    double sellSL = sellEntry + PipsToPrice(StopLossPips);
    double sellTP = sellEntry - PipsToPrice(TakeProfitPips);
    DrawPredictionLine("SellSL", sellSL, clrIndianRed, STYLE_DOT,
                      StringFormat("SELL SL: %.5f (-%.1f pips)", sellSL, StopLossPips));
    DrawPredictionLine("SellTP", sellTP, clrLimeGreen, STYLE_DOT,
                      StringFormat("SELL TP: %.5f (+%.1f pips)", sellTP, TakeProfitPips));
}

//+------------------------------------------------------------------+
//| 予測ライン描画ヘルパー                                           |
//+------------------------------------------------------------------+
void DrawPredictionLine(string id, double price, color clr, int style, string text) {
    string name = PREFIX + id;
    
    if(ObjectFind(0, name) < 0) {
        ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
    }
    ObjectSetDouble(0, name, OBJPROP_PRICE, price);
    ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, name, OBJPROP_STYLE, style);
    ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
    ObjectSetString(0, name, OBJPROP_TEXT, text);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| アラートチェック                                                  |
//+------------------------------------------------------------------+
void CheckForAlerts() {
    if(!EnableAlerts) return;
    if(TimeCurrent() - g_lastAlertTime < g_alertCooldown) return;
    
    double currentPrice = iClose(Symbol(), PERIOD_M5, 0);
    double buyEntry = g_currentPattern.upperBoundary + PipsToPrice(BreakoutMinPips);
    double sellEntry = g_currentPattern.lowerBoundary - PipsToPrice(BreakoutMinPips);
    
    // 買いエントリー接近
    if(MathAbs(currentPrice - buyEntry) <= PipsToPrice(AlertDistancePips)) {
        Alert("FX5M: Price approaching BUY entry at ", buyEntry);
        g_lastAlertTime = TimeCurrent();
    }
    // 売りエントリー接近
    else if(MathAbs(currentPrice - sellEntry) <= PipsToPrice(AlertDistancePips)) {
        Alert("FX5M: Price approaching SELL entry at ", sellEntry);
        g_lastAlertTime = TimeCurrent();
    }
}

//+------------------------------------------------------------------+
//| 情報パネル作成                                                    |
//+------------------------------------------------------------------+
void CreateInfoPanel() {
    int x = 10;
    int y = 50;
    int lineHeight = 15;
    
    // パネル背景
    string bgName = PREFIX + "InfoBG";
    if(ObjectFind(0, bgName) < 0) {
        ObjectCreate(0, bgName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
    }
    ObjectSetInteger(0, bgName, OBJPROP_XDISTANCE, x - 5);
    ObjectSetInteger(0, bgName, OBJPROP_YDISTANCE, y - 5);
    ObjectSetInteger(0, bgName, OBJPROP_XSIZE, 300);
    ObjectSetInteger(0, bgName, OBJPROP_YSIZE, 200);
    ObjectSetInteger(0, bgName, OBJPROP_BGCOLOR, clrBlack);
    ObjectSetInteger(0, bgName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, bgName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, bgName, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, bgName, OBJPROP_WIDTH, 1);
    ObjectSetInteger(0, bgName, OBJPROP_BACK, true);
    ObjectSetInteger(0, bgName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, bgName, OBJPROP_SELECTED, false);
    ObjectSetInteger(0, bgName, OBJPROP_HIDDEN, false);
    ObjectSetInteger(0, bgName, OBJPROP_COLOR, clrWhite);
}

//+------------------------------------------------------------------+
//| 情報パネル更新                                                    |
//+------------------------------------------------------------------+
void UpdateInfoPanel() {
    int x = 15;
    int y = 55;
    int lineHeight = 15;
    int line = 0;
    
    // タイトル
    CreateLabel("Title", x, y + lineHeight * line++, 
               "=== FX 5分足スキャルピング ===", clrYellow);
    line++;
    
    // パターン状態
    CreateLabel("Pattern", x, y + lineHeight * line++,
               StringFormat("パターン: %s", g_patternActive ? "検出中" : "なし"),
               g_patternActive ? clrLime : clrGray);
    
    if(g_patternActive) {
        // レンジ情報
        CreateLabel("Range", x, y + lineHeight * line++,
                   StringFormat("レンジ: %.5f - %.5f (%.1f pips)",
                   g_currentPattern.lowerBoundary, g_currentPattern.upperBoundary,
                   PriceToPips(g_currentPattern.upperBoundary - g_currentPattern.lowerBoundary)),
                   clrWhite);
        
        // ビルドアップ情報
        CreateLabel("Buildup", x, y + lineHeight * line++,
                   StringFormat("ビルドアップ: %dバー %.1fpips (品質%d%%)",
                   g_currentBuildup.barCount, g_currentBuildup.rangeSize, g_currentBuildup.quality),
                   clrYellow);
        
        line++;
        
        // 次のアクション
        double buyEntry = g_currentPattern.upperBoundary + PipsToPrice(BreakoutMinPips);
        double sellEntry = g_currentPattern.lowerBoundary - PipsToPrice(BreakoutMinPips);
        
        CreateLabel("NextAction", x, y + lineHeight * line++,
                   "【次のアクション】", clrAqua);
        CreateLabel("BuyAction", x, y + lineHeight * line++,
                   StringFormat("↑ %.5fで買い", buyEntry),
                   BuySignalColor);
        CreateLabel("SellAction", x, y + lineHeight * line++,
                   StringFormat("↓ %.5fで売り", sellEntry),
                   SellSignalColor);
        
        line++;
        
        // 推奨設定
        double lots = CalculateLotSize();
        CreateLabel("Recommendation", x, y + lineHeight * line++,
                   "【推奨設定】", clrAqua);
        CreateLabel("Lots", x, y + lineHeight * line++,
                   StringFormat("ロット: %.2f (リスク%.1f%%)", lots, RiskPercent),
                   clrWhite);
        CreateLabel("RR", x, y + lineHeight * line++,
                   StringFormat("R/R比: 1:%.1f", TakeProfitPips/StopLossPips),
                   clrWhite);
    }
}

//+------------------------------------------------------------------+
//| ラベル作成ヘルパー                                               |
//+------------------------------------------------------------------+
void CreateLabel(string id, int x, int y, string text, color clr) {
    string name = PREFIX + "Info_" + id;
    
    if(ObjectFind(0, name) < 0) {
        ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
    }
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
    ObjectSetString(0, name, OBJPROP_TEXT, text);
    ObjectSetString(0, name, OBJPROP_FONT, FONT_NAME);
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE, FONT_SIZE);
    ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| ロットサイズ計算                                                  |
//+------------------------------------------------------------------+
double CalculateLotSize() {
    double balance = AccountBalance();
    double riskAmount = balance * RiskPercent / 100.0;
    double pipValue = MarketInfo(Symbol(), MODE_TICKVALUE);
    
    if(Digits == 3 || Digits == 5) {
        pipValue = pipValue * 10;
    }
    
    double lots = riskAmount / (StopLossPips * pipValue);
    lots = NormalizeDouble(lots, 2);
    
    double minLot = MarketInfo(Symbol(), MODE_MINLOT);
    double maxLot = MarketInfo(Symbol(), MODE_MAXLOT);
    
    if(lots < minLot) lots = minLot;
    if(lots > maxLot) lots = maxLot;
    
    return lots;
}

//+------------------------------------------------------------------+
//| pipsを価格に変換                                                 |
//+------------------------------------------------------------------+
double PipsToPrice(double pips) {
    double point = Point;
    if(Digits == 3 || Digits == 5) {
        point = Point * 10;
    }
    return pips * point;
}

//+------------------------------------------------------------------+
//| 価格をpipsに変換                                                 |
//+------------------------------------------------------------------+
double PriceToPips(double price) {
    double point = Point;
    if(Digits == 3 || Digits == 5) {
        point = Point * 10;
    }
    return price / point;
}