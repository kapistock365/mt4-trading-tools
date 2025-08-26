//+------------------------------------------------------------------+
//|                                           FX5MinScalpingEA.mq4  |
//|                   FX 5分足スキャルピング メインEA                |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, FX5MinScalping"
#property link      "https://github.com/kapistock365/mt4-trading-tools"
#property version   "1.00"
#property strict
#property description "Bob Volman's 5-minute scalping method implementation"

// インクルード
#include <FX5MinScalping/PatternBreakPlugin.mqh>

//+------------------------------------------------------------------+
//| 入力パラメータ                                                   |
//+------------------------------------------------------------------+
// === 基本設定 ===
input string    Section1            = "=== Basic Settings ===";
input int       MagicNumber         = 20250825;           // マジックナンバー
input double    RiskPercent         = 2.0;                // リスク率（%）
input double    DefaultLots         = 0.01;               // 固定ロット（リスク率0の場合）
input bool      UseAutoLot          = true;               // 自動ロット計算

// === パターンブレイク設定 ===
input string    Section2            = "=== Pattern Break Settings ===";
input bool      EnablePatternBreak  = true;               // パターンブレイク有効
input int       MinBuildupBars      = 3;                  // 最小ビルドアップバー数
input int       MaxBuildupBars      = 10;                 // 最大ビルドアップバー数
input double    BuildupRangePips    = 10.0;               // ビルドアップ最大幅（pips）
input double    BreakoutMinPips     = 0.5;                // ブレイク最小幅（pips）
input double    BreakoutMaxPips     = 5.0;                // ブレイク最大幅（pips）
input int       ConfirmationBars    = 1;                  // ブレイク確認バー数

// === エントリー/エグジット設定 ===
input string    Section3            = "=== Entry/Exit Settings ===";
input double    StopLossPips        = 10.0;               // 損切り（pips）
input double    TakeProfitPips      = 20.0;               // 利確（pips）
input bool      UseTrailingStop     = true;               // トレーリングストップ使用
input double    TrailingStartPips   = 10.0;               // トレーリング開始（pips）
input double    TrailingStepPips    = 5.0;                // トレーリングステップ（pips）
input bool      UseBreakEven        = true;               // ブレークイーブン使用
input double    BreakEvenTrigger    = 5.0;                // ブレークイーブントリガー（pips）

// === フィルター設定 ===
input string    Section4            = "=== Filter Settings ===";
input double    MaxEMADistance      = 15.0;               // EMAからの最大距離（pips）
input double    MaxSpreadPips       = 3.0;                // 最大スプレッド（pips）
input bool      UseTimeFilter       = true;               // 時間フィルター使用
input int       StartHour           = 7;                  // 開始時間（サーバー時間）
input int       EndHour             = 21;                 // 終了時間（サーバー時間）

// === リスク管理設定 ===
input string    Section5            = "=== Risk Management ===";
input int       MaxTradesPerDay     = 5;                  // 1日の最大トレード数
input double    MaxDailyLoss        = 5.0;                // 日次最大損失（%）
input int       CooldownMinutes     = 30;                 // クールダウン時間（分）
input int       MaxConcurrentTrades = 1;                  // 最大同時ポジション数

// === 表示設定 ===
input string    Section6            = "=== Display Settings ===";
input bool      ShowInfoPanel       = true;               // 情報パネル表示
input bool      ShowSignalArrows    = true;               // シグナル矢印表示
input bool      EnableAlerts        = true;               // アラート有効
input bool      EnableNotifications = false;              // プッシュ通知有効

//+------------------------------------------------------------------+
//| グローバル変数                                                   |
//+------------------------------------------------------------------+
CPatternBreakPlugin* g_patternBreakPlugin = NULL;

// 統計情報
int    g_todayTrades = 0;
double g_todayProfit = 0;
double g_todayLoss = 0;
int    g_winTrades = 0;
int    g_lossTrades = 0;
datetime g_lastTradeTime = 0;

// パネル関連
string g_panelName = "FX5MinScalping_Panel";
int    g_panelX = 10;
int    g_panelY = 30;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    Print("=== FX 5-Minute Scalping EA Initializing ===");
    
    // 時間軸チェック
    if(Period() != PERIOD_M5) {
        Alert("This EA is designed for M5 timeframe only!");
        // 警告は出すが続行
    }
    
    // パターンブレイクプラグイン初期化
    if(EnablePatternBreak) {
        g_patternBreakPlugin = new CPatternBreakPlugin();
        g_patternBreakPlugin.SetParameters(
            MinBuildupBars,
            MaxBuildupBars,
            BuildupRangePips,
            BreakoutMinPips,
            BreakoutMaxPips,
            MaxEMADistance,
            ConfirmationBars,
            StopLossPips,
            TakeProfitPips,
            RiskPercent
        );
        
        if(!g_patternBreakPlugin.Enable()) {
            Print("Failed to enable PatternBreak plugin");
            return INIT_FAILED;
        }
        Print("PatternBreak plugin enabled successfully");
    }
    
    // 情報パネル作成
    if(ShowInfoPanel) {
        CreateInfoPanel();
    }
    
    // タイマー設定（1秒毎）
    EventSetTimer(1);
    
    Print("=== FX 5-Minute Scalping EA Initialized Successfully ===");
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    Print("=== FX 5-Minute Scalping EA Deinitializing ===");
    
    // タイマー停止
    EventKillTimer();
    
    // プラグイン削除
    if(g_patternBreakPlugin != NULL) {
        g_patternBreakPlugin.Disable();
        delete g_patternBreakPlugin;
        g_patternBreakPlugin = NULL;
    }
    
    // パネル削除
    DeleteInfoPanel();
    
    // オブジェクト削除
    ObjectsDeleteAll(0, "FX5Min_");
    
    Print("=== FX 5-Minute Scalping EA Deinitialized ===");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
    // リスクチェック
    if(!CheckRiskLimits()) {
        return;
    }
    
    // 時間フィルター
    if(UseTimeFilter && !IsGoodTradingTime()) {
        return;
    }
    
    // スプレッドチェック
    if(!CheckSpread()) {
        return;
    }
    
    // プラグイン処理
    if(g_patternBreakPlugin != NULL) {
        g_patternBreakPlugin.OnTick();
        
        // シグナルチェック
        SignalInfo signal = g_patternBreakPlugin.GetLastSignal();
        if(signal.isValid && TimeCurrent() - signal.generatedTime < 5) {
            ProcessSignal(signal);
        }
    }
    
    // ポジション管理
    ManagePositions();
    
    // 統計更新
    UpdateStatistics();
}

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer() {
    // パネル更新
    if(ShowInfoPanel) {
        UpdateInfoPanel();
    }
    
    // プラグインタイマー処理
    if(g_patternBreakPlugin != NULL) {
        g_patternBreakPlugin.OnTimer();
    }
    
    // 日次リセット
    static int lastDay = -1;
    int currentDay = TimeDay(TimeCurrent());
    if(currentDay != lastDay) {
        ResetDailyStats();
        lastDay = currentDay;
    }
}

//+------------------------------------------------------------------+
//| Trade function                                                   |
//+------------------------------------------------------------------+
void OnTrade() {
    // プラグイントレード処理
    if(g_patternBreakPlugin != NULL) {
        g_patternBreakPlugin.OnTrade();
    }
}

//+------------------------------------------------------------------+
//| リスク制限チェック                                               |
//+------------------------------------------------------------------+
bool CheckRiskLimits() {
    // 最大同時ポジション数チェック
    int openPositions = CountOpenPositions();
    if(openPositions >= MaxConcurrentTrades) {
        return false;
    }
    
    // 日次最大トレード数チェック
    if(g_todayTrades >= MaxTradesPerDay) {
        return false;
    }
    
    // 日次最大損失チェック
    double dailyLossPercent = (g_todayLoss > 0) ? (g_todayLoss / AccountBalance()) * 100 : 0;
    if(dailyLossPercent >= MaxDailyLoss) {
        return false;
    }
    
    // クールダウンチェック
    if(TimeCurrent() - g_lastTradeTime < CooldownMinutes * 60) {
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| 取引時間チェック                                                 |
//+------------------------------------------------------------------+
bool IsGoodTradingTime() {
    datetime currentTime = TimeCurrent();
    int hour = TimeHour(currentTime);
    
    if(StartHour < EndHour) {
        return (hour >= StartHour && hour < EndHour);
    } else {
        // 日をまたぐ場合
        return (hour >= StartHour || hour < EndHour);
    }
}

//+------------------------------------------------------------------+
//| スプレッドチェック                                               |
//+------------------------------------------------------------------+
bool CheckSpread() {
    double spread = MarketInfo(Symbol(), MODE_SPREAD);
    double spreadPips = spread * Point;
    if(Digits == 3 || Digits == 5) spreadPips *= 10;
    
    return (spreadPips <= MaxSpreadPips);
}

//+------------------------------------------------------------------+
//| シグナル処理                                                     |
//+------------------------------------------------------------------+
void ProcessSignal(SignalInfo &signal) {
    // アラート
    if(EnableAlerts) {
        Alert("Signal: ", signal.setupName, " ", 
              (signal.signalType > 0) ? "BUY" : "SELL");
    }
    
    // プッシュ通知
    if(EnableNotifications) {
        SendNotification("FX5Min: " + signal.setupName);
    }
    
    // 矢印表示
    if(ShowSignalArrows) {
        DrawSignalArrow(signal);
    }
}

//+------------------------------------------------------------------+
//| ポジション管理                                                   |
//+------------------------------------------------------------------+
void ManagePositions() {
    for(int i = OrdersTotal() - 1; i >= 0; i--) {
        if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
        if(OrderSymbol() != Symbol()) continue;
        if(OrderMagicNumber() != MagicNumber) continue;
        
        // トレーリングストップ
        if(UseTrailingStop) {
            ApplyTrailingStop(OrderTicket());
        }
        
        // ブレークイーブン
        if(UseBreakEven) {
            ApplyBreakEven(OrderTicket());
        }
    }
}

//+------------------------------------------------------------------+
//| トレーリングストップ適用                                         |
//+------------------------------------------------------------------+
void ApplyTrailingStop(int ticket) {
    if(!OrderSelect(ticket, SELECT_BY_TICKET)) return;
    
    double point = Point * ((Digits == 3 || Digits == 5) ? 10 : 1);
    double triggerDistance = TrailingStartPips * point;
    double trailDistance = TrailingStepPips * point;
    
    if(OrderType() == OP_BUY) {
        double profit = Bid - OrderOpenPrice();
        if(profit >= triggerDistance) {
            double newSL = Bid - trailDistance;
            if(newSL > OrderStopLoss()) {
                if(!OrderModify(ticket, OrderOpenPrice(), newSL, OrderTakeProfit(), 0, clrNONE)) {
                    Print("Failed to modify trailing stop (buy): ", GetLastError());
                }
            }
        }
    } else if(OrderType() == OP_SELL) {
        double profit = OrderOpenPrice() - Ask;
        if(profit >= triggerDistance) {
            double newSL = Ask + trailDistance;
            if(newSL < OrderStopLoss() || OrderStopLoss() == 0) {
                if(!OrderModify(ticket, OrderOpenPrice(), newSL, OrderTakeProfit(), 0, clrNONE)) {
                    Print("Failed to modify trailing stop (sell): ", GetLastError());
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| ブレークイーブン適用                                             |
//+------------------------------------------------------------------+
void ApplyBreakEven(int ticket) {
    if(!OrderSelect(ticket, SELECT_BY_TICKET)) return;
    
    double point = Point * ((Digits == 3 || Digits == 5) ? 10 : 1);
    double triggerDistance = BreakEvenTrigger * point;
    
    if(OrderType() == OP_BUY) {
        double profit = Bid - OrderOpenPrice();
        if(profit >= triggerDistance && OrderStopLoss() < OrderOpenPrice()) {
            if(!OrderModify(ticket, OrderOpenPrice(), OrderOpenPrice() + point, 
                       OrderTakeProfit(), 0, clrNONE)) {
                Print("Failed to set break even (buy): ", GetLastError());
            }
        }
    } else if(OrderType() == OP_SELL) {
        double profit = OrderOpenPrice() - Ask;
        if(profit >= triggerDistance && OrderStopLoss() > OrderOpenPrice()) {
            if(!OrderModify(ticket, OrderOpenPrice(), OrderOpenPrice() - point, 
                       OrderTakeProfit(), 0, clrNONE)) {
                Print("Failed to set break even (sell): ", GetLastError());
            }
        }
    }
}

//+------------------------------------------------------------------+
//| オープンポジション数カウント                                     |
//+------------------------------------------------------------------+
int CountOpenPositions() {
    int count = 0;
    
    for(int i = OrdersTotal() - 1; i >= 0; i--) {
        if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
        if(OrderSymbol() != Symbol()) continue;
        if(OrderMagicNumber() != MagicNumber) continue;
        count++;
    }
    
    return count;
}

//+------------------------------------------------------------------+
//| 統計更新                                                         |
//+------------------------------------------------------------------+
void UpdateStatistics() {
    g_todayTrades = 0;
    g_todayProfit = 0;
    g_todayLoss = 0;
    g_winTrades = 0;
    g_lossTrades = 0;
    
    datetime todayStart = iTime(Symbol(), PERIOD_D1, 0);
    
    // 本日の取引を集計
    for(int i = OrdersHistoryTotal() - 1; i >= 0; i--) {
        if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;
        if(OrderSymbol() != Symbol()) continue;
        if(OrderMagicNumber() != MagicNumber) continue;
        if(OrderOpenTime() < todayStart) continue;
        
        g_todayTrades++;
        
        double profit = OrderProfit() + OrderSwap() + OrderCommission();
        if(profit >= 0) {
            g_todayProfit += profit;
            g_winTrades++;
        } else {
            g_todayLoss += MathAbs(profit);
            g_lossTrades++;
        }
    }
}

//+------------------------------------------------------------------+
//| 日次統計リセット                                                 |
//+------------------------------------------------------------------+
void ResetDailyStats() {
    g_todayTrades = 0;
    g_todayProfit = 0;
    g_todayLoss = 0;
    g_winTrades = 0;
    g_lossTrades = 0;
    
    Print("Daily statistics reset");
}

//+------------------------------------------------------------------+
//| 情報パネル作成                                                   |
//+------------------------------------------------------------------+
void CreateInfoPanel() {
    int y = g_panelY;
    
    // 背景
    ObjectCreate(0, g_panelName + "_bg", OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, g_panelName + "_bg", OBJPROP_XDISTANCE, g_panelX);
    ObjectSetInteger(0, g_panelName + "_bg", OBJPROP_YDISTANCE, y);
    ObjectSetInteger(0, g_panelName + "_bg", OBJPROP_XSIZE, 250);
    ObjectSetInteger(0, g_panelName + "_bg", OBJPROP_YSIZE, 200);
    ObjectSetInteger(0, g_panelName + "_bg", OBJPROP_BGCOLOR, clrBlack);
    ObjectSetInteger(0, g_panelName + "_bg", OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, g_panelName + "_bg", OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, g_panelName + "_bg", OBJPROP_BACK, false);
    
    // タイトル
    CreateLabel(g_panelName + "_title", "FX 5Min Scalping EA", g_panelX + 10, y + 10, clrYellow, 10);
    
    // ラベル作成
    y += 35;
    CreateLabel(g_panelName + "_status", "Status: Active", g_panelX + 10, y, clrLime, 9);
    
    y += 20;
    CreateLabel(g_panelName + "_trades", "Today Trades: 0", g_panelX + 10, y, clrWhite, 9);
    
    y += 20;
    CreateLabel(g_panelName + "_winloss", "Win/Loss: 0/0", g_panelX + 10, y, clrWhite, 9);
    
    y += 20;
    CreateLabel(g_panelName + "_profit", "Today P&L: 0.00", g_panelX + 10, y, clrWhite, 9);
    
    y += 20;
    CreateLabel(g_panelName + "_winrate", "Win Rate: 0%", g_panelX + 10, y, clrWhite, 9);
    
    y += 20;
    CreateLabel(g_panelName + "_spread", "Spread: 0.0", g_panelX + 10, y, clrWhite, 9);
    
    y += 20;
    CreateLabel(g_panelName + "_session", "Session: -", g_panelX + 10, y, clrWhite, 9);
}

//+------------------------------------------------------------------+
//| ラベル作成ヘルパー                                               |
//+------------------------------------------------------------------+
void CreateLabel(string name, string text, int x, int y, color clr, int size) {
    ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
    ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE, size);
    ObjectSetString(0, name, OBJPROP_TEXT, text);
    ObjectSetString(0, name, OBJPROP_FONT, "Arial");
    ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
}

//+------------------------------------------------------------------+
//| 情報パネル更新                                                   |
//+------------------------------------------------------------------+
void UpdateInfoPanel() {
    // ステータス
    string status = "Active";
    color statusColor = clrLime;
    
    if(g_todayTrades >= MaxTradesPerDay) {
        status = "Max Trades";
        statusColor = clrOrange;
    } else if((g_todayLoss / AccountBalance()) * 100 >= MaxDailyLoss) {
        status = "Max Loss";
        statusColor = clrRed;
    }
    
    ObjectSetString(0, g_panelName + "_status", OBJPROP_TEXT, "Status: " + status);
    ObjectSetInteger(0, g_panelName + "_status", OBJPROP_COLOR, statusColor);
    
    // トレード数
    ObjectSetString(0, g_panelName + "_trades", OBJPROP_TEXT, 
        "Today Trades: " + IntegerToString(g_todayTrades) + "/" + IntegerToString(MaxTradesPerDay));
    
    // 勝敗
    ObjectSetString(0, g_panelName + "_winloss", OBJPROP_TEXT, 
        "Win/Loss: " + IntegerToString(g_winTrades) + "/" + IntegerToString(g_lossTrades));
    
    // 損益
    double todayPL = g_todayProfit - g_todayLoss;
    color plColor = (todayPL >= 0) ? clrLime : clrRed;
    ObjectSetString(0, g_panelName + "_profit", OBJPROP_TEXT, 
        "Today P&L: " + DoubleToString(todayPL, 2));
    ObjectSetInteger(0, g_panelName + "_profit", OBJPROP_COLOR, plColor);
    
    // 勝率
    double winRate = (g_todayTrades > 0) ? (double)g_winTrades / g_todayTrades * 100 : 0;
    ObjectSetString(0, g_panelName + "_winrate", OBJPROP_TEXT, 
        "Win Rate: " + DoubleToString(winRate, 1) + "%");
    
    // スプレッド
    double spread = MarketInfo(Symbol(), MODE_SPREAD);
    double spreadPips = spread * Point;
    if(Digits == 3 || Digits == 5) spreadPips *= 10;
    color spreadColor = (spreadPips <= MaxSpreadPips) ? clrLime : clrRed;
    ObjectSetString(0, g_panelName + "_spread", OBJPROP_TEXT, 
        "Spread: " + DoubleToString(spreadPips, 1));
    ObjectSetInteger(0, g_panelName + "_spread", OBJPROP_COLOR, spreadColor);
    
    // セッション
    string session = GetCurrentSession();
    ObjectSetString(0, g_panelName + "_session", OBJPROP_TEXT, "Session: " + session);
}

//+------------------------------------------------------------------+
//| 現在のセッション取得                                             |
//+------------------------------------------------------------------+
string GetCurrentSession() {
    int hour = TimeHour(TimeCurrent());
    
    if(hour >= 0 && hour < 8) return "Asian";
    if(hour >= 7 && hour < 12) return "London";
    if(hour >= 12 && hour < 16) return "London-NY";
    if(hour >= 16 && hour < 21) return "New York";
    
    return "Off-hours";
}

//+------------------------------------------------------------------+
//| 情報パネル削除                                                   |
//+------------------------------------------------------------------+
void DeleteInfoPanel() {
    ObjectsDeleteAll(0, g_panelName);
}

//+------------------------------------------------------------------+
//| シグナル矢印描画                                                 |
//+------------------------------------------------------------------+
void DrawSignalArrow(SignalInfo &signal) {
    string name = "FX5Min_signal_" + TimeToString(signal.generatedTime);
    
    if(signal.signalType > 0) {
        ObjectCreate(0, name, OBJ_ARROW_UP, 0, signal.generatedTime, signal.entryPrice);
        ObjectSetInteger(0, name, OBJPROP_COLOR, clrLime);
    } else {
        ObjectCreate(0, name, OBJ_ARROW_DOWN, 0, signal.generatedTime, signal.entryPrice);
        ObjectSetInteger(0, name, OBJPROP_COLOR, clrRed);
    }
    
    ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
    ObjectSetInteger(0, name, OBJPROP_ARROWCODE, 233);
}

//+------------------------------------------------------------------+