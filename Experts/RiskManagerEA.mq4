//+------------------------------------------------------------------+
//|                                              RiskManagerEA.mq4   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property link      ""
#property version   "1.00"
#property strict

// インプットパラメータ
input double MaxLossPerTrade = 2.0;        // 1トレードあたり最大損失（%）
input double DailyMaxLoss = 5.0;           // 1日の最大損失（%）
input double TrailingStopStart = 10.0;     // トレイリングストップ開始（pips）
input double TrailingStopDistance = 5.0;   // トレイリングストップ幅（pips）
input bool   UsePartialClose = true;       // 部分決済を使用
input double PartialCloseProfit = 10.0;    // 部分決済開始利益（pips）
input double PartialClosePercent = 50.0;   // 部分決済割合（%）
input bool   UseBreakEven = true;          // ブレークイーブン機能
input double BreakEvenProfit = 5.0;        // ブレークイーブン開始（pips）
input bool   AlertOnStopLoss = true;       // 損切り時にアラート
input bool   CloseAllOnDailyLimit = true;  // 日次制限到達時に全決済

// グローバル変数
datetime currentDay = 0;
double dailyLoss = 0;
double initialBalance = 0;
bool dailyLimitReached = false;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    initialBalance = AccountBalance();
    currentDay = TimeDay(TimeCurrent());
    
    // 既存ポジションに損切りを設定
    SetStopLossForAllPositions();
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // 日付が変わったらリセット
    if(TimeDay(TimeCurrent()) != currentDay)
    {
        currentDay = TimeDay(TimeCurrent());
        dailyLoss = 0;
        dailyLimitReached = false;
        initialBalance = AccountBalance();
    }
    
    // 日次損失制限チェック
    if(CheckDailyLossLimit())
    {
        if(CloseAllOnDailyLimit && !dailyLimitReached)
        {
            CloseAllPositions();
            Alert("日次損失制限に到達しました。全ポジションを決済しました。");
            dailyLimitReached = true;
        }
        return;
    }
    
    // 各ポジションの管理
    ManagePositions();
}

//+------------------------------------------------------------------+
//| ポジション管理                                                   |
//+------------------------------------------------------------------+
void ManagePositions()
{
    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
            if(OrderSymbol() != Symbol()) continue;
            
            // 損切りが設定されていない場合は設定
            if(OrderStopLoss() == 0)
            {
                SetStopLoss(OrderTicket());
            }
            
            // 利益が出ているポジションの管理
            double profitPips = CalculateProfitInPips(OrderTicket());
            
            // ブレークイーブン
            if(UseBreakEven && profitPips >= BreakEvenProfit)
            {
                MoveToBreakEven(OrderTicket());
            }
            
            // 部分決済
            if(UsePartialClose && profitPips >= PartialCloseProfit)
            {
                PartialClosePosition(OrderTicket());
            }
            
            // トレーリングストップ
            if(profitPips >= TrailingStopStart)
            {
                TrailingStop(OrderTicket());
            }
        }
    }
}

//+------------------------------------------------------------------+
//| 損切り設定                                                       |
//+------------------------------------------------------------------+
void SetStopLoss(int ticket)
{
    if(!OrderSelect(ticket, SELECT_BY_TICKET)) return;
    
    double stopLossDistance = (initialBalance * MaxLossPerTrade / 100.0) / 
                             (OrderLots() * MarketInfo(Symbol(), MODE_TICKVALUE));
    stopLossDistance = stopLossDistance * Point;
    
    double stopLoss = 0;
    
    if(OrderType() == OP_BUY)
    {
        stopLoss = OrderOpenPrice() - stopLossDistance;
    }
    else if(OrderType() == OP_SELL)
    {
        stopLoss = OrderOpenPrice() + stopLossDistance;
    }
    
    if(stopLoss > 0 && OrderModify(ticket, OrderOpenPrice(), stopLoss, OrderTakeProfit(), 0, clrRed))
    {
        Print("損切り設定: チケット ", ticket, " SL: ", stopLoss);
    }
}

//+------------------------------------------------------------------+
//| 全ポジションに損切り設定                                         |
//+------------------------------------------------------------------+
void SetStopLossForAllPositions()
{
    for(int i = 0; i < OrdersTotal(); i++)
    {
        if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
            if(OrderSymbol() == Symbol() && OrderStopLoss() == 0)
            {
                SetStopLoss(OrderTicket());
            }
        }
    }
}

//+------------------------------------------------------------------+
//| ブレークイーブンに移動                                           |
//+------------------------------------------------------------------+
void MoveToBreakEven(int ticket)
{
    if(!OrderSelect(ticket, SELECT_BY_TICKET)) return;
    
    double newStopLoss = 0;
    
    if(OrderType() == OP_BUY)
    {
        newStopLoss = OrderOpenPrice() + Point;
        if(OrderStopLoss() < newStopLoss && Bid > OrderOpenPrice() + BreakEvenProfit * Point * 10)
        {
            OrderModify(ticket, OrderOpenPrice(), newStopLoss, OrderTakeProfit(), 0, clrGreen);
        }
    }
    else if(OrderType() == OP_SELL)
    {
        newStopLoss = OrderOpenPrice() - Point;
        if(OrderStopLoss() > newStopLoss && Ask < OrderOpenPrice() - BreakEvenProfit * Point * 10)
        {
            OrderModify(ticket, OrderOpenPrice(), newStopLoss, OrderTakeProfit(), 0, clrGreen);
        }
    }
}

//+------------------------------------------------------------------+
//| トレーリングストップ                                             |
//+------------------------------------------------------------------+
void TrailingStop(int ticket)
{
    if(!OrderSelect(ticket, SELECT_BY_TICKET)) return;
    
    double trailDistance = TrailingStopDistance * Point * 10;
    
    if(OrderType() == OP_BUY)
    {
        double newStopLoss = Bid - trailDistance;
        if(newStopLoss > OrderStopLoss() && newStopLoss > OrderOpenPrice())
        {
            OrderModify(ticket, OrderOpenPrice(), newStopLoss, OrderTakeProfit(), 0, clrBlue);
        }
    }
    else if(OrderType() == OP_SELL)
    {
        double newStopLoss = Ask + trailDistance;
        if(newStopLoss < OrderStopLoss() && newStopLoss < OrderOpenPrice())
        {
            OrderModify(ticket, OrderOpenPrice(), newStopLoss, OrderTakeProfit(), 0, clrBlue);
        }
    }
}

//+------------------------------------------------------------------+
//| 部分決済                                                         |
//+------------------------------------------------------------------+
void PartialClosePosition(int ticket)
{
    if(!OrderSelect(ticket, SELECT_BY_TICKET)) return;
    
    // すでに部分決済済みかチェック
    if(OrderComment() == "partial_closed") return;
    
    double lotToClose = NormalizeDouble(OrderLots() * PartialClosePercent / 100.0, 2);
    
    if(lotToClose >= MarketInfo(Symbol(), MODE_MINLOT))
    {
        if(OrderClose(ticket, lotToClose, 
                     OrderType() == OP_BUY ? Bid : Ask, 
                     3, clrYellow))
        {
            Print("部分決済実行: ", lotToClose, " lots");
        }
    }
}

//+------------------------------------------------------------------+
//| 利益をpipsで計算                                                 |
//+------------------------------------------------------------------+
double CalculateProfitInPips(int ticket)
{
    if(!OrderSelect(ticket, SELECT_BY_TICKET)) return 0;
    
    double profit = 0;
    
    if(OrderType() == OP_BUY)
    {
        profit = (Bid - OrderOpenPrice()) / Point / 10;
    }
    else if(OrderType() == OP_SELL)
    {
        profit = (OrderOpenPrice() - Ask) / Point / 10;
    }
    
    return profit;
}

//+------------------------------------------------------------------+
//| 日次損失制限チェック                                             |
//+------------------------------------------------------------------+
bool CheckDailyLossLimit()
{
    double currentBalance = AccountBalance();
    double todayLoss = initialBalance - currentBalance;
    double lossPercent = (todayLoss / initialBalance) * 100;
    
    return lossPercent >= DailyMaxLoss;
}

//+------------------------------------------------------------------+
//| 全ポジション決済                                                 |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
            if(OrderSymbol() == Symbol())
            {
                OrderClose(OrderTicket(), OrderLots(), 
                          OrderType() == OP_BUY ? Bid : Ask, 
                          3, clrRed);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| 注文決済時の処理                                                 |
//+------------------------------------------------------------------+
void OnTrade()
{
    // 損切りによる決済を検出してアラート
    if(AlertOnStopLoss)
    {
        for(int i = OrdersHistoryTotal() - 1; i >= 0; i--)
        {
            if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
            {
                if(OrderSymbol() == Symbol() && 
                   OrderCloseTime() > TimeCurrent() - 60 &&
                   OrderProfit() < 0)
                {
                    Alert("損切り実行: ", OrderSymbol(), " 損失: ", 
                          DoubleToString(OrderProfit(), 2));
                }
            }
        }
    }
}
//+------------------------------------------------------------------+