//+------------------------------------------------------------------+
//|                                               RiskMonitor.mq4    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property link      ""
#property version   "1.00"
#property strict
#property indicator_chart_window

// インプットパラメータ
input int    DisplayX = 10;                // 表示X位置
input int    DisplayY = 50;                // 表示Y位置
input color  ProfitColor = clrLime;        // 利益時の色
input color  LossColor = clrRed;           // 損失時の色
input color  NormalColor = clrWhite;       // 通常時の色
input int    FontSize = 10;                // フォントサイズ
input bool   ShowDailyStats = true;        // 日次統計を表示
input bool   ShowRiskReward = true;        // リスクリワード比を表示
input double MaxDailyLossPercent = 5.0;    // 最大日次損失（%）

// グローバル変数
datetime currentDay = 0;
double dailyStartBalance = 0;
int winCount = 0;
int lossCount = 0;
double totalProfit = 0;
double totalLoss = 0;

//+------------------------------------------------------------------+
//| カスタムインジケーター初期化関数                                 |
//+------------------------------------------------------------------+
int OnInit()
{
    // オブジェクトの作成
    CreateDisplayObjects();
    
    // 初期値設定
    currentDay = TimeDay(TimeCurrent());
    dailyStartBalance = AccountBalance();
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| カスタムインジケーター計算関数                                   |
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
                const int &spread[])
{
    // 日付が変わったらリセット
    if(TimeDay(TimeCurrent()) != currentDay)
    {
        ResetDailyStats();
    }
    
    // 統計情報の更新
    UpdateStats();
    
    // 表示の更新
    UpdateDisplay();
    
    return(rates_total);
}

//+------------------------------------------------------------------+
//| 表示オブジェクトの作成                                           |
//+------------------------------------------------------------------+
void CreateDisplayObjects()
{
    string objects[] = {
        "RM_Balance",
        "RM_DailyPL",
        "RM_OpenPositions",
        "RM_TotalRisk",
        "RM_WinRate",
        "RM_RiskReward",
        "RM_Warning"
    };
    
    for(int i = 0; i < ArraySize(objects); i++)
    {
        ObjectCreate(0, objects[i], OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, objects[i], OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, objects[i], OBJPROP_XDISTANCE, DisplayX);
        ObjectSetInteger(0, objects[i], OBJPROP_YDISTANCE, DisplayY + i * 20);
        ObjectSetString(0, objects[i], OBJPROP_FONT, "Arial");
        ObjectSetInteger(0, objects[i], OBJPROP_FONTSIZE, FontSize);
        ObjectSetInteger(0, objects[i], OBJPROP_COLOR, NormalColor);
    }
}

//+------------------------------------------------------------------+
//| 表示の更新                                                       |
//+------------------------------------------------------------------+
void UpdateDisplay()
{
    // 現在の残高
    string balanceText = StringFormat("残高: %.2f", AccountBalance());
    ObjectSetString(0, "RM_Balance", OBJPROP_TEXT, balanceText);
    
    // 日次損益
    double dailyPL = AccountBalance() - dailyStartBalance;
    double dailyPLPercent = (dailyPL / dailyStartBalance) * 100;
    string dailyPLText = StringFormat("本日損益: %.2f (%.2f%%)", dailyPL, dailyPLPercent);
    ObjectSetString(0, "RM_DailyPL", OBJPROP_TEXT, dailyPLText);
    ObjectSetInteger(0, "RM_DailyPL", OBJPROP_COLOR, 
                    dailyPL >= 0 ? ProfitColor : LossColor);
    
    // オープンポジション情報
    int posCount = 0;
    double totalRisk = 0;
    double totalProfit = 0;
    
    for(int i = 0; i < OrdersTotal(); i++)
    {
        if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
            if(OrderSymbol() == Symbol())
            {
                posCount++;
                double risk = CalculatePositionRisk(OrderTicket());
                totalRisk += risk;
                totalProfit += OrderProfit();
            }
        }
    }
    
    string posText = StringFormat("ポジション数: %d | 含み損益: %.2f", 
                                 posCount, totalProfit);
    ObjectSetString(0, "RM_OpenPositions", OBJPROP_TEXT, posText);
    ObjectSetInteger(0, "RM_OpenPositions", OBJPROP_COLOR, 
                    totalProfit >= 0 ? ProfitColor : LossColor);
    
    // 総リスク
    string riskText = StringFormat("総リスク: %.2f (%.2f%%)", 
                                  totalRisk, (totalRisk / AccountBalance()) * 100);
    ObjectSetString(0, "RM_TotalRisk", OBJPROP_TEXT, riskText);
    
    // 勝率
    if(ShowDailyStats && (winCount + lossCount) > 0)
    {
        double winRate = (double)winCount / (winCount + lossCount) * 100;
        string winRateText = StringFormat("本日勝率: %.1f%% (%d勝%d敗)", 
                                         winRate, winCount, lossCount);
        ObjectSetString(0, "RM_WinRate", OBJPROP_TEXT, winRateText);
    }
    
    // リスクリワード比
    if(ShowRiskReward && totalLoss != 0)
    {
        double rrRatio = MathAbs(totalProfit / totalLoss);
        string rrText = StringFormat("RR比: %.2f", rrRatio);
        ObjectSetString(0, "RM_RiskReward", OBJPROP_TEXT, rrText);
    }
    
    // 警告表示
    if(dailyPLPercent <= -MaxDailyLossPercent)
    {
        ObjectSetString(0, "RM_Warning", OBJPROP_TEXT, 
                       "⚠️ 日次損失制限に到達！取引を停止してください");
        ObjectSetInteger(0, "RM_Warning", OBJPROP_COLOR, LossColor);
    }
    else if(dailyPLPercent <= -MaxDailyLossPercent * 0.8)
    {
        ObjectSetString(0, "RM_Warning", OBJPROP_TEXT, 
                       "⚠️ 日次損失制限に近づいています");
        ObjectSetInteger(0, "RM_Warning", OBJPROP_COLOR, clrYellow);
    }
    else
    {
        ObjectSetString(0, "RM_Warning", OBJPROP_TEXT, "");
    }
}

//+------------------------------------------------------------------+
//| ポジションのリスク計算                                           |
//+------------------------------------------------------------------+
double CalculatePositionRisk(int ticket)
{
    if(!OrderSelect(ticket, SELECT_BY_TICKET)) return 0;
    
    if(OrderStopLoss() == 0) return 0;
    
    double risk = 0;
    
    if(OrderType() == OP_BUY)
    {
        risk = (OrderOpenPrice() - OrderStopLoss()) * OrderLots() * 
               MarketInfo(Symbol(), MODE_TICKVALUE) / Point;
    }
    else if(OrderType() == OP_SELL)
    {
        risk = (OrderStopLoss() - OrderOpenPrice()) * OrderLots() * 
               MarketInfo(Symbol(), MODE_TICKVALUE) / Point;
    }
    
    return risk;
}

//+------------------------------------------------------------------+
//| 統計情報の更新                                                   |
//+------------------------------------------------------------------+
void UpdateStats()
{
    // 本日の取引履歴をチェック
    for(int i = OrdersHistoryTotal() - 1; i >= 0; i--)
    {
        if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
        {
            if(OrderSymbol() == Symbol() && 
               TimeDay(OrderCloseTime()) == currentDay)
            {
                // すでにカウント済みかチェック
                static int lastCountedTicket = 0;
                if(OrderTicket() <= lastCountedTicket) continue;
                
                if(OrderProfit() > 0)
                {
                    winCount++;
                    totalProfit += OrderProfit();
                }
                else if(OrderProfit() < 0)
                {
                    lossCount++;
                    totalLoss += OrderProfit();
                }
                
                lastCountedTicket = OrderTicket();
            }
        }
    }
}

//+------------------------------------------------------------------+
//| 日次統計のリセット                                               |
//+------------------------------------------------------------------+
void ResetDailyStats()
{
    currentDay = TimeDay(TimeCurrent());
    dailyStartBalance = AccountBalance();
    winCount = 0;
    lossCount = 0;
    totalProfit = 0;
    totalLoss = 0;
}

//+------------------------------------------------------------------+
//| インジケーター終了時の処理                                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // オブジェクトの削除
    ObjectsDeleteAll(0, "RM_");
}
//+------------------------------------------------------------------+