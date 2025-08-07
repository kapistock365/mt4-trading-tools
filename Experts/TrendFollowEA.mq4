//+------------------------------------------------------------------+
//|                                               TrendFollowEA.mq4  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property link      ""
#property version   "1.00"
#property strict

// 既存ライブラリのインクルード
#include "../CT_Trail_2.00/Include/OrderManager.mqh"
#include "../CT_Trail_2.00/Include/AccountManager.mqh"

// インプットパラメータ
input double Lots = 0.1;                    // ロット数（自動計算しない場合）
input double Target = 20.0;                 // 利確（pips）
input double Stop = 10.0;                   // 損切（pips）
input bool   UseAutoLotSize = true;        // 自動ロット計算を使用
input double RiskPercent = 1.0;            // リスク割合（%）
input double BaseLotSize = 100000.0;       // 基準ロットサイズ
input bool   UseTrailingStop = true;       // トレーリングストップを使用
input double Trail = 5.0;                  // トレーリング幅（pips）
input int    LookbackPeriod = 20;         // ブレイクアウト判定期間
input double BreakoutBuffer = 2.0;        // ブレイクアウトバッファ（pips）
input bool   TradeOnlyWithTrend = true;   // トレンド方向のみ取引
input int    MaxPositions = 1;            // 最大ポジション数
input int    CooldownMinutes = 30;        // エントリー後のクールダウン時間（分）

// グローバル変数
COrderManager* g_orderManager = NULL;
CAccountManager* g_accountManager = NULL;
datetime lastTradeTime = 0;
double lastBreakLevel = 0;
string lastBreakType = "";

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // アカウントマネージャーの初期化
    g_accountManager = new CAccountManager(UseAutoLotSize, RiskPercent, BaseLotSize, true, 9);
    
    // ロットサイズの計算
    double actualLots = Lots;
    if(UseAutoLotSize) {
        actualLots = g_accountManager.CalculateLotSize();
        Print("自動計算されたロットサイズ: ", actualLots);
    }
    
    // オーダーマネージャーの初期化
    g_orderManager = new COrderManager(actualLots, Target, Stop, 0, 1000, true, UseTrailingStop, Trail);
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    if(g_orderManager != NULL) {
        delete g_orderManager;
        g_orderManager = NULL;
    }
    
    if(g_accountManager != NULL) {
        delete g_accountManager;
        g_accountManager = NULL;
    }
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // ポジション管理
    if(UseTrailingStop) {
        g_orderManager.ManageTrailingStop();
    }
    
    // 最大ポジション数チェック
    if(CountOpenPositions() >= MaxPositions) {
        return;
    }
    
    // クールダウンチェック
    if(TimeCurrent() - lastTradeTime < CooldownMinutes * 60) {
        return;
    }
    
    // ブレイクアウトの検出
    CheckBreakout();
}

//+------------------------------------------------------------------+
//| ブレイクアウトをチェック                                         |
//+------------------------------------------------------------------+
void CheckBreakout()
{
    // サポート・レジスタンスレベルの計算
    double support = Low[iLowest(NULL, 0, MODE_LOW, LookbackPeriod, 1)];
    double resistance = High[iHighest(NULL, 0, MODE_HIGH, LookbackPeriod, 1)];
    double bufferSize = BreakoutBuffer * Point * 10;
    
    // トレンド判定
    string currentTrend = GetCurrentTrend();
    
    // 上昇ブレイクアウト
    if(Close[0] > resistance + bufferSize && Close[1] <= resistance + bufferSize)
    {
        if(!TradeOnlyWithTrend || currentTrend == "UPTREND")
        {
            if(lastBreakType != "BULLISH" || MathAbs(resistance - lastBreakLevel) > 10 * Point)
            {
                Print("上昇ブレイクアウト検出: ", resistance);
                if(g_orderManager.PlaceBuyOrder(true))
                {
                    lastTradeTime = TimeCurrent();
                    lastBreakType = "BULLISH";
                    lastBreakLevel = resistance;
                }
            }
        }
    }
    
    // 下降ブレイクアウト
    if(Close[0] < support - bufferSize && Close[1] >= support - bufferSize)
    {
        if(!TradeOnlyWithTrend || currentTrend == "DOWNTREND")
        {
            if(lastBreakType != "BEARISH" || MathAbs(support - lastBreakLevel) > 10 * Point)
            {
                Print("下降ブレイクアウト検出: ", support);
                if(g_orderManager.PlaceSellOrder(true))
                {
                    lastTradeTime = TimeCurrent();
                    lastBreakType = "BEARISH";
                    lastBreakLevel = support;
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| 現在のトレンドを判定                                             |
//+------------------------------------------------------------------+
string GetCurrentTrend()
{
    double ma20 = iMA(NULL, 0, 20, 0, MODE_SMA, PRICE_CLOSE, 0);
    double ma50 = iMA(NULL, 0, 50, 0, MODE_SMA, PRICE_CLOSE, 0);
    
    if(ma20 > ma50 && Close[0] > ma20) {
        return "UPTREND";
    }
    else if(ma20 < ma50 && Close[0] < ma20) {
        return "DOWNTREND";
    }
    
    return "NEUTRAL";
}

//+------------------------------------------------------------------+
//| オープンポジション数をカウント                                   |
//+------------------------------------------------------------------+
int CountOpenPositions()
{
    int count = 0;
    for(int i = 0; i < OrdersTotal(); i++)
    {
        if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
            if(OrderSymbol() == Symbol() && OrderMagicNumber() == 0)
            {
                count++;
            }
        }
    }
    return count;
}

//+------------------------------------------------------------------+
//| チャート上に情報を表示                                           |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
    // 必要に応じてチャートイベントを処理
}
//+------------------------------------------------------------------+