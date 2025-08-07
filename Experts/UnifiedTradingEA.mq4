//+------------------------------------------------------------------+
//|                                           UnifiedTradingEA.mq4   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property link      ""
#property version   "1.00"
#property strict
#property description "統合トレーディングEA - プラグインシステム"

// インクルード
#include "../Include/PluginBase.mqh"
#include "../Include/Plugins/BreakoutPlugin.mqh"
#include "../Include/Plugins/RiskManagerPlugin.mqh"
#include "../CT_Trail_2.00/Include/OrderManager.mqh"
#include "../CT_Trail_2.00/Include/AccountManager.mqh"

// インプットパラメータ（基本設定）
input string  sep1 = "=== 基本設定 ===";               // -----
input double  Lots = 0.1;                              // ロット数
input bool    UseAutoLotSize = true;                  // 自動ロット計算
input double  RiskPercent = 1.0;                      // リスク割合（%）
input double  Target = 20.0;                          // 利確（pips）
input double  Stop = 10.0;                            // 損切（pips）

input string  sep2 = "=== プラグイン設定 ===";         // -----
input bool    EnableBreakout = true;                  // ブレイクアウトプラグイン
input bool    EnableRiskManager = true;               // リスク管理プラグイン
input bool    EnableTrailingStop = true;              // トレーリングストップ

input string  sep3 = "=== GUI設定 ===";                // -----
input int     PanelX = 10;                            // パネルX位置
input int     PanelY = 50;                            // パネルY位置
input bool    ShowPanel = true;                       // パネル表示

// グローバル変数
CPluginManager* g_pluginManager = NULL;
COrderManager* g_orderManager = NULL;
CAccountManager* g_accountManager = NULL;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // マネージャーの初期化
    g_pluginManager = new CPluginManager();
    g_accountManager = new CAccountManager(UseAutoLotSize, RiskPercent, 100000.0, true, 9);
    
    // ロットサイズの計算
    double actualLots = Lots;
    if(UseAutoLotSize) {
        actualLots = g_accountManager.CalculateLotSize();
        Print("自動計算されたロットサイズ: ", actualLots);
    }
    
    // オーダーマネージャーの初期化
    g_orderManager = new COrderManager(actualLots, Target, Stop, 0, 1000, true, EnableTrailingStop, 5.0);
    
    // プラグインの登録
    if(EnableBreakout) {
        CBreakoutPlugin* breakoutPlugin = new CBreakoutPlugin(g_orderManager);
        g_pluginManager.RegisterPlugin(breakoutPlugin);
    }
    
    if(EnableRiskManager) {
        CRiskManagerPlugin* riskPlugin = new CRiskManagerPlugin();
        g_pluginManager.RegisterPlugin(riskPlugin);
    }
    
    // 全プラグインの初期化
    g_pluginManager.InitializeAll();
    
    // GUIの作成
    if(ShowPanel) {
        CreateMainPanel();
    }
    
    // タイマーの設定（1秒ごと）
    EventSetTimer(1);
    
    Print("UnifiedTradingEA 初期化完了");
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // タイマーの停止
    EventKillTimer();
    
    // GUIの削除
    ObjectsDeleteAll(0, "UTE_");
    
    // マネージャーの削除
    if(g_pluginManager != NULL) {
        delete g_pluginManager;
        g_pluginManager = NULL;
    }
    
    if(g_orderManager != NULL) {
        delete g_orderManager;
        g_orderManager = NULL;
    }
    
    if(g_accountManager != NULL) {
        delete g_accountManager;
        g_accountManager = NULL;
    }
    
    Print("UnifiedTradingEA 終了");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // ロットサイズの更新（自動計算の場合）
    if(UseAutoLotSize) {
        double newLots = g_accountManager.CalculateLotSize();
        g_orderManager.UpdateLotSize(newLots);
    }
    
    // プラグインのOnTickを呼び出し
    g_pluginManager.OnTick();
    
    // 情報の更新
    if(ShowPanel) {
        UpdateInfoPanel();
    }
}

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
{
    // プラグインのOnTimerを呼び出し
    g_pluginManager.OnTimer();
}

//+------------------------------------------------------------------+
//| Trade function                                                   |
//+------------------------------------------------------------------+
void OnTrade()
{
    // プラグインのOnTradeを呼び出し
    g_pluginManager.OnTrade();
}

//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
    // プラグインのOnChartEventを呼び出し
    g_pluginManager.OnChartEvent(id, lparam, dparam, sparam);
    
    // メインパネルのイベント処理
    if(id == CHARTEVENT_OBJECT_CLICK) {
        if(sparam == "UTE_CloseAll") {
            if(MessageBox("全ポジションを決済しますか？", "確認", MB_YESNO) == IDYES) {
                g_orderManager.CloseAllPositions();
            }
        }
        else if(sparam == "UTE_Settings") {
            // 設定パネルの表示/非表示
            ToggleSettingsPanel();
        }
    }
}

//+------------------------------------------------------------------+
//| メインパネルの作成                                               |
//+------------------------------------------------------------------+
void CreateMainPanel()
{
    int y = PanelY;
    
    // タイトル
    CreateLabel("UTE_Title", "【統合トレーディングEA】", PanelX, y, clrGold, 14);
    y += 30;
    
    // 口座情報
    CreateLabel("UTE_Balance", "残高: " + DoubleToString(AccountBalance(), 2), PanelX, y);
    y += 20;
    
    CreateLabel("UTE_Equity", "有効証拠金: " + DoubleToString(AccountEquity(), 2), PanelX, y);
    y += 20;
    
    // 現在のロットサイズ
    CreateLabel("UTE_LotSize", "ロットサイズ: " + DoubleToString(g_orderManager.GetLots(), 2), PanelX, y);
    y += 20;
    
    // プラグイン状態
    CreateLabel("UTE_PluginStatus", "アクティブプラグイン: " + IntegerToString(g_pluginManager.GetPluginCount()), PanelX, y);
    y += 30;
    
    // ボタン
    CreateButton("UTE_CloseAll", "全決済", PanelX, y, 100, 30, clrRed);
    CreateButton("UTE_Settings", "設定", PanelX + 110, y, 100, 30, clrDodgerBlue);
    y += 40;
    
    // プラグイン設定パネルの作成
    CreateSettingsPanel();
}

//+------------------------------------------------------------------+
//| 設定パネルの作成                                                 |
//+------------------------------------------------------------------+
void CreateSettingsPanel()
{
    int y = PanelY + 200;
    
    // 背景
    ObjectCreate(0, "UTE_SettingsBG", OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, "UTE_SettingsBG", OBJPROP_XDISTANCE, PanelX - 5);
    ObjectSetInteger(0, "UTE_SettingsBG", OBJPROP_YDISTANCE, y - 5);
    ObjectSetInteger(0, "UTE_SettingsBG", OBJPROP_XSIZE, 250);
    ObjectSetInteger(0, "UTE_SettingsBG", OBJPROP_YSIZE, 400);
    ObjectSetInteger(0, "UTE_SettingsBG", OBJPROP_BGCOLOR, clrDarkSlateGray);
    ObjectSetInteger(0, "UTE_SettingsBG", OBJPROP_HIDDEN, true);
    
    // 各プラグインの設定パネルを作成
    for(int i = 0; i < g_pluginManager.GetPluginCount(); i++) {
        // プラグインごとの設定UIを作成
        // （プラグインのCreateSettingsPanelメソッドを呼び出し）
    }
}

//+------------------------------------------------------------------+
//| 設定パネルの表示/非表示                                          |
//+------------------------------------------------------------------+
void ToggleSettingsPanel()
{
    bool hidden = ObjectGetInteger(0, "UTE_SettingsBG", OBJPROP_HIDDEN);
    
    // 背景の表示/非表示
    ObjectSetInteger(0, "UTE_SettingsBG", OBJPROP_HIDDEN, !hidden);
    
    // 各プラグインの設定項目の表示/非表示
    string prefixes[] = {"BP_", "RM_"};  // プラグインのプレフィックス
    
    for(int i = 0; i < ArraySize(prefixes); i++) {
        int total = ObjectsTotal(0);
        for(int j = 0; j < total; j++) {
            string name = ObjectName(0, j);
            if(StringFind(name, prefixes[i]) == 0) {
                ObjectSetInteger(0, name, OBJPROP_HIDDEN, !hidden);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| 情報パネルの更新                                                 |
//+------------------------------------------------------------------+
void UpdateInfoPanel()
{
    ObjectSetString(0, "UTE_Balance", OBJPROP_TEXT, "残高: " + DoubleToString(AccountBalance(), 2));
    ObjectSetString(0, "UTE_Equity", OBJPROP_TEXT, "有効証拠金: " + DoubleToString(AccountEquity(), 2));
    ObjectSetString(0, "UTE_LotSize", OBJPROP_TEXT, "ロットサイズ: " + DoubleToString(g_orderManager.GetLots(), 2));
    
    // 含み損益の計算と表示
    double totalProfit = 0;
    int openPositions = 0;
    
    for(int i = 0; i < OrdersTotal(); i++) {
        if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
            if(OrderSymbol() == Symbol()) {
                totalProfit += OrderProfit();
                openPositions++;
            }
        }
    }
    
    if(openPositions > 0) {
        color profitColor = totalProfit >= 0 ? clrLime : clrRed;
        CreateLabel("UTE_OpenProfit", "含み損益: " + DoubleToString(totalProfit, 2) + 
                   " (" + IntegerToString(openPositions) + ")", PanelX, PanelY + 90, profitColor);
    } else {
        ObjectDelete(0, "UTE_OpenProfit");
    }
}

//+------------------------------------------------------------------+
//| GUI作成ヘルパー関数                                              |
//+------------------------------------------------------------------+
void CreateLabel(string name, string text, int x, int y, color clr = clrWhite, int size = 10)
{
    if(ObjectFind(0, name) < 0) {
        ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    }
    
    ObjectSetString(0, name, OBJPROP_TEXT, text);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
    ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
    ObjectSetString(0, name, OBJPROP_FONT, "Arial");
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE, size);
}

void CreateButton(string name, string text, int x, int y, int width, int height, color bgColor)
{
    if(ObjectFind(0, name) < 0) {
        ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
        ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    }
    
    ObjectSetString(0, name, OBJPROP_TEXT, text);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
    ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
    ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
    ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bgColor);
    ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
}
//+------------------------------------------------------------------+