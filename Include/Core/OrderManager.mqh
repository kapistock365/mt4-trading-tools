//+------------------------------------------------------------------+
//|                                                 OrderManager.mqh |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property strict

// 注文管理クラス
// CT_Trail_2.00から移植・改良
// Constants.mqhへの依存を削除し、必要な定数を内包

// 注文タイプ（内部使用）
enum ENUM_ORDER_ACTION {
    ORDER_ACTION_BUY_MARKET,     // 買い（成行）
    ORDER_ACTION_BUY_PENDING,    // 買い（指値）
    ORDER_ACTION_SELL_MARKET,    // 売り（成行）
    ORDER_ACTION_SELL_PENDING,   // 売り（指値）
    ORDER_ACTION_DUAL_MARKET,    // 両建て（成行）
    ORDER_ACTION_DUAL_PENDING    // 両建て（指値）
};

// リトライ設定
#define ORDER_RETRY_COUNT        3
#define ORDER_RETRY_DELAY        1000

class COrderManager
{
private:
    // 設定値
    double m_lots;
    double m_target;
    double m_stop;
    double m_margin;
    int m_sleepTime;
    bool m_isPipsX10;
    bool m_useTrailingStop;
    double m_trail;
    
    // オーダー管理
    int m_lastBuyTicket;
    int m_lastSellTicket;
    
    // 内部メソッド
    double NormalizePips(double pips);
    bool PlaceOrder(int orderType, double price, double sl, double tp, string comment = "");
    double CalculateInternalValue(double value);
    
public:
    // コンストラクタ
    COrderManager(double lots, double target, double stop, double margin, 
                 int sleepTime, bool isPipsX10, bool useTrailingStop, double trail);
    
    // デストラクタ
    ~COrderManager() {};
    
    // 注文管理メソッド
    bool PlaceOrderByAction(ENUM_ORDER_ACTION action);
    bool PlaceBuyOrder(bool isMarket, string comment = "");
    bool PlaceSellOrder(bool isMarket, string comment = "");
    bool PlaceDualOrders(bool isMarket);
    void CheckOrders();
    int GetOpenOrderType();
    void CloseAllPositions();
    bool ClosePosition(int ticket);
    
    // トレーリングストップ管理
    void ManageTrailingStop();
    void SetTrailingStop(int ticket, double trailPips);
    
    // 部分決済（新規追加）
    bool PartialClosePosition(int ticket, double percent);
    
    // ロットサイズ更新
    void UpdateLotSize(double newLots) { m_lots = newLots; }
    
    // セッターメソッド（新規追加）
    void SetTarget(double target) { m_target = target; }
    void SetStop(double stop) { m_stop = stop; }
    void SetTrailingStop(bool useTrailing) { m_useTrailingStop = useTrailing; }
    void SetTrailDistance(double trail) { m_trail = trail; }
    
    // ゲッターメソッド
    double GetLots() { return m_lots; }
    double GetTarget() { return m_target; }
    double GetStop() { return m_stop; }
    double GetMargin() { return m_margin; }
    double GetTrail() { return m_trail; }
    bool GetUseTrailingStop() { return m_useTrailingStop; }
    int GetLastBuyTicket() { return m_lastBuyTicket; }
    int GetLastSellTicket() { return m_lastSellTicket; }
    bool GetIsPipsX10() { return m_isPipsX10; }
    
    // ユーティリティメソッド（新規追加）
    int CountOpenPositions();
    double CalculateTotalProfit();
    double CalculateTotalLots();
};

//+------------------------------------------------------------------+
//| コンストラクタ                                                     |
//+------------------------------------------------------------------+
COrderManager::COrderManager(double lots, double target, double stop, double margin, 
                           int sleepTime, bool isPipsX10, bool useTrailingStop, double trail)
{
    m_lots = lots;
    m_target = target;
    m_stop = stop;
    m_margin = margin;
    m_sleepTime = sleepTime;
    m_isPipsX10 = isPipsX10;
    m_useTrailingStop = useTrailingStop;
    m_trail = trail;
    
    m_lastBuyTicket = 0;
    m_lastSellTicket = 0;
}

//+------------------------------------------------------------------+
//| Pips値の正規化                                                     |
//+------------------------------------------------------------------+
double COrderManager::NormalizePips(double pips)
{
    return m_isPipsX10 ? pips * 10 : pips;
}

//+------------------------------------------------------------------+
//| 内部計算用の値を計算                                               |
//+------------------------------------------------------------------+
double COrderManager::CalculateInternalValue(double value)
{
    return NormalizePips(value) * Point;
}

//+------------------------------------------------------------------+
//| 注文アクションに基づいて注文を発注                                 |
//+------------------------------------------------------------------+
bool COrderManager::PlaceOrderByAction(ENUM_ORDER_ACTION action)
{
    switch(action) {
        case ORDER_ACTION_BUY_MARKET:
            return PlaceBuyOrder(true);
        case ORDER_ACTION_BUY_PENDING:
            return PlaceBuyOrder(false);
        case ORDER_ACTION_SELL_MARKET:
            return PlaceSellOrder(true);
        case ORDER_ACTION_SELL_PENDING:
            return PlaceSellOrder(false);
        case ORDER_ACTION_DUAL_MARKET:
            return PlaceDualOrders(true);
        case ORDER_ACTION_DUAL_PENDING:
            return PlaceDualOrders(false);
        default:
            return false;
    }
}

//+------------------------------------------------------------------+
//| 買い注文発注                                                       |
//+------------------------------------------------------------------+
bool COrderManager::PlaceBuyOrder(bool isMarket, string comment = "")
{
    double internalTarget = CalculateInternalValue(m_target);
    double internalStop = CalculateInternalValue(m_stop);
    double internalMargin = CalculateInternalValue(m_margin);
    
    double buyPrice;
    int orderType;
    
    if(isMarket) {
        buyPrice = Ask;
        orderType = OP_BUY;
    } else {
        buyPrice = Ask + internalMargin;
        orderType = OP_BUYSTOP;
    }
    
    double stopLoss = buyPrice - internalStop;
    double takeProfit = buyPrice + internalTarget;
    
    // ストップレベルのチェック
    double minStop = MarketInfo(Symbol(), MODE_STOPLEVEL) * Point;
    if(MathAbs(buyPrice - stopLoss) < minStop) {
        stopLoss = buyPrice - minStop;
    }
    if(MathAbs(takeProfit - buyPrice) < minStop) {
        takeProfit = buyPrice + minStop;
    }
    
    if(PlaceOrder(orderType, buyPrice, stopLoss, takeProfit, comment)) {
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| 売り注文発注                                                       |
//+------------------------------------------------------------------+
bool COrderManager::PlaceSellOrder(bool isMarket, string comment = "")
{
    double internalTarget = CalculateInternalValue(m_target);
    double internalStop = CalculateInternalValue(m_stop);
    double internalMargin = CalculateInternalValue(m_margin);
    
    double sellPrice;
    int orderType;
    
    if(isMarket) {
        sellPrice = Bid;
        orderType = OP_SELL;
    } else {
        sellPrice = Bid - internalMargin;
        orderType = OP_SELLSTOP;
    }
    
    double stopLoss = sellPrice + internalStop;
    double takeProfit = sellPrice - internalTarget;
    
    // ストップレベルのチェック
    double minStop = MarketInfo(Symbol(), MODE_STOPLEVEL) * Point;
    if(MathAbs(stopLoss - sellPrice) < minStop) {
        stopLoss = sellPrice + minStop;
    }
    if(MathAbs(sellPrice - takeProfit) < minStop) {
        takeProfit = sellPrice - minStop;
    }
    
    if(PlaceOrder(orderType, sellPrice, stopLoss, takeProfit, comment)) {
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| 両建て注文発注                                                     |
//+------------------------------------------------------------------+
bool COrderManager::PlaceDualOrders(bool isMarket)
{
    // 買い注文を発注
    if(!PlaceBuyOrder(isMarket, "Dual_Buy")) {
        return false;
    }
    
    // 発注間隔を空ける
    Sleep(m_sleepTime);
    
    // 売り注文を発注
    if(!PlaceSellOrder(isMarket, "Dual_Sell")) {
        // 売り注文失敗の場合、買い注文をキャンセル
        if(m_lastBuyTicket > 0) {
            if(OrderSelect(m_lastBuyTicket, SELECT_BY_TICKET)) {
                if(OrderType() > OP_SELL) {  // ペンディングオーダーの場合
                    OrderDelete(m_lastBuyTicket);
                } else {  // ポジションの場合
                    OrderClose(m_lastBuyTicket, OrderLots(), Bid, 3);
                }
                m_lastBuyTicket = 0;
            }
        }
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| 単一注文発注                                                       |
//+------------------------------------------------------------------+
bool COrderManager::PlaceOrder(int orderType, double price, double sl, double tp, string comment = "")
{
    int ticket = -1;
    
    // リトライロジック
    for(int i = 0; i < ORDER_RETRY_COUNT; i++) {
        ResetLastError();
        
        ticket = OrderSend(Symbol(), orderType, m_lots, price, 3, sl, tp, comment, 0, 0, 
                          orderType == OP_BUY || orderType == OP_BUYSTOP ? clrBlue : clrRed);
        
        if(ticket > 0) {
            // 注文成功
            if(orderType == OP_BUY || orderType == OP_BUYSTOP) {
                m_lastBuyTicket = ticket;
            } else if(orderType == OP_SELL || orderType == OP_SELLSTOP) {
                m_lastSellTicket = ticket;
            }
            Print("注文成功: チケット=", ticket, " タイプ=", orderType);
            return true;
        }
        
        int error = GetLastError();
        Print("注文エラー: ", error, " - ", ErrorDescription(error));
        
        // 失敗した場合は少し待ってリトライ
        Sleep(ORDER_RETRY_DELAY);
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| 注文確認                                                           |
//+------------------------------------------------------------------+
void COrderManager::CheckOrders()
{
    // オープンオーダーの数が2の場合
    int currentOrdersTotal = OrdersTotal();
    
    if(currentOrdersTotal == 2 && (m_lastBuyTicket > 0 || m_lastSellTicket > 0)) {
        int opType = GetOpenOrderType();
        
        if(opType == OP_BUY) {
            // 残りのSELLストップオーダーをキャンセル
            if(OrderSelect(m_lastSellTicket, SELECT_BY_TICKET)) {
                OrderDelete(m_lastSellTicket);
                m_lastSellTicket = 0;
            }
        } else if(opType == OP_SELL) {
            // 残りのBUYストップオーダーをキャンセル
            if(OrderSelect(m_lastBuyTicket, SELECT_BY_TICKET)) {
                OrderDelete(m_lastBuyTicket);
                m_lastBuyTicket = 0;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| オープンポジションのタイプを取得                                   |
//+------------------------------------------------------------------+
int COrderManager::GetOpenOrderType()
{
    for(int i = OrdersTotal() - 1; i >= 0; i--) {
        if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
            if(OrderSymbol() == Symbol()) {
                if(OrderType() == OP_BUY) return OP_BUY;
                if(OrderType() == OP_SELL) return OP_SELL;
            }
        }
    }
    return -1;
}

//+------------------------------------------------------------------+
//| トレーリングストップ管理                                            |
//+------------------------------------------------------------------+
void COrderManager::ManageTrailingStop()
{
    if(!m_useTrailingStop) return;
    
    for(int i = 0; i < OrdersTotal(); i++) {
        if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
            if(OrderSymbol() == Symbol() && 
               (OrderType() == OP_BUY || OrderType() == OP_SELL)) {
                
                SetTrailingStop(OrderTicket(), m_trail);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| 個別のトレーリングストップ設定                                     |
//+------------------------------------------------------------------+
void COrderManager::SetTrailingStop(int ticket, double trailPips)
{
    if(!OrderSelect(ticket, SELECT_BY_TICKET)) return;
    if(OrderSymbol() != Symbol()) return;
    
    double internalTrail = CalculateInternalValue(trailPips);
    double currentProfit = 0;
    double newStopLoss = 0;
    
    if(OrderType() == OP_BUY) {
        currentProfit = (Bid - OrderOpenPrice()) / Point;
        if(currentProfit > internalTrail / Point) {
            newStopLoss = Bid - internalTrail;
            if(OrderStopLoss() == 0 || newStopLoss > OrderStopLoss()) {
                bool result = OrderModify(OrderTicket(), OrderOpenPrice(), 
                                        newStopLoss, OrderTakeProfit(), 0, clrBlue);
                if(result) {
                    Print("トレーリングストップ更新: チケット=", ticket, " 新SL=", newStopLoss);
                }
            }
        }
    }
    else if(OrderType() == OP_SELL) {
        currentProfit = (OrderOpenPrice() - Ask) / Point;
        if(currentProfit > internalTrail / Point) {
            newStopLoss = Ask + internalTrail;
            if(OrderStopLoss() == 0 || newStopLoss < OrderStopLoss()) {
                bool result = OrderModify(OrderTicket(), OrderOpenPrice(), 
                                        newStopLoss, OrderTakeProfit(), 0, clrRed);
                if(result) {
                    Print("トレーリングストップ更新: チケット=", ticket, " 新SL=", newStopLoss);
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| 全ポジション決済                                                   |
//+------------------------------------------------------------------+
void COrderManager::CloseAllPositions()
{
    for(int i = OrdersTotal() - 1; i >= 0; i--) {
        if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
            if(OrderSymbol() == Symbol()) {
                if(OrderType() <= OP_SELL) {
                    bool result = OrderClose(OrderTicket(), OrderLots(), 
                                           OrderType() == OP_BUY ? Bid : Ask, 3);
                    if(result) {
                        Print("ポジション決済: チケット=", OrderTicket());
                    }
                }
                else {
                    bool result = OrderDelete(OrderTicket());
                    if(result) {
                        Print("ペンディング注文削除: チケット=", OrderTicket());
                    }
                }
            }
        }
    }
    
    // チケットをリセット
    m_lastBuyTicket = 0;
    m_lastSellTicket = 0;
}

//+------------------------------------------------------------------+
//| 個別ポジション決済                                                 |
//+------------------------------------------------------------------+
bool COrderManager::ClosePosition(int ticket)
{
    if(!OrderSelect(ticket, SELECT_BY_TICKET)) return false;
    if(OrderSymbol() != Symbol()) return false;
    
    if(OrderType() <= OP_SELL) {
        return OrderClose(ticket, OrderLots(), 
                         OrderType() == OP_BUY ? Bid : Ask, 3);
    }
    else {
        return OrderDelete(ticket);
    }
}

//+------------------------------------------------------------------+
//| 部分決済                                                           |
//+------------------------------------------------------------------+
bool COrderManager::PartialClosePosition(int ticket, double percent)
{
    if(!OrderSelect(ticket, SELECT_BY_TICKET)) return false;
    if(OrderSymbol() != Symbol()) return false;
    if(OrderType() > OP_SELL) return false;  // ペンディングオーダーは不可
    
    double lotToClose = NormalizeDouble(OrderLots() * percent / 100.0, 2);
    double minLot = MarketInfo(Symbol(), MODE_MINLOT);
    
    if(lotToClose < minLot) return false;
    
    return OrderClose(ticket, lotToClose, 
                     OrderType() == OP_BUY ? Bid : Ask, 3);
}

//+------------------------------------------------------------------+
//| オープンポジション数をカウント                                     |
//+------------------------------------------------------------------+
int COrderManager::CountOpenPositions()
{
    int count = 0;
    for(int i = 0; i < OrdersTotal(); i++) {
        if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
            if(OrderSymbol() == Symbol() && OrderType() <= OP_SELL) {
                count++;
            }
        }
    }
    return count;
}

//+------------------------------------------------------------------+
//| 総利益計算                                                         |
//+------------------------------------------------------------------+
double COrderManager::CalculateTotalProfit()
{
    double totalProfit = 0.0;
    for(int i = 0; i < OrdersTotal(); i++) {
        if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
            if(OrderSymbol() == Symbol()) {
                totalProfit += OrderProfit() + OrderSwap() + OrderCommission();
            }
        }
    }
    return totalProfit;
}

//+------------------------------------------------------------------+
//| 総ロット数計算                                                     |
//+------------------------------------------------------------------+
double COrderManager::CalculateTotalLots()
{
    double totalLots = 0.0;
    for(int i = 0; i < OrdersTotal(); i++) {
        if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
            if(OrderSymbol() == Symbol() && OrderType() <= OP_SELL) {
                totalLots += OrderLots();
            }
        }
    }
    return totalLots;
}

//+------------------------------------------------------------------+
//| エラーコードの説明取得                                             |
//+------------------------------------------------------------------+
string ErrorDescription(int error)
{
    switch(error) {
        case 0: return "エラーなし";
        case 1: return "エラーはあるが詳細不明";
        case 2: return "共通エラー";
        case 3: return "無効なトレードパラメーター";
        case 4: return "トレードサーバーがビジー";
        case 5: return "クライアントターミナルの旧バージョン";
        case 6: return "トレードサーバーに接続されていない";
        case 7: return "権限が不十分";
        case 8: return "リクエストが頻繁すぎる";
        case 9: return "トレードオペレーションを妨げる不正な操作";
        case 64: return "アカウントがブロックされている";
        case 65: return "無効なアカウント";
        case 128: return "トレードタイムアウト";
        case 129: return "無効な価格";
        case 130: return "無効なストップロス";
        case 131: return "無効なボリューム";
        case 132: return "マーケットがクローズ";
        case 133: return "トレードが無効";
        case 134: return "資金不足";
        case 135: return "価格が変更された";
        case 136: return "オフクオート";
        case 137: return "ブローカーがビジー";
        case 138: return "リクオート";
        case 139: return "注文がロックされている";
        case 140: return "買い注文のみ許可";
        case 141: return "リクエストが多すぎる";
        case 145: return "修正が拒否された。注文がマーケットに近すぎる";
        case 146: return "トレードコンテキストがビジー";
        case 147: return "ブローカーによって有効期限の使用が拒否された";
        case 148: return "オープンおよびペンディング注文の数がブローカーによって設定された制限に達した";
        default: return "不明なエラー";
    }
}
//+------------------------------------------------------------------+