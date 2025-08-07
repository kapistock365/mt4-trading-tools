//+------------------------------------------------------------------+
//|                                               AccountManager.mqh |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property strict

// 口座管理クラス
// CT_Trail_2.00から移植・改良
class CAccountManager
{
private:
    bool m_useAutoLotSize;     // 自動ロットサイズ計算の使用有無
    double m_riskPercent;      // リスク割合（％）
    double m_baseLotSize;      // 基準ロットサイズ
    bool m_IsPipsX10;          // pipsがポイントになるブローカーの場合True
    int m_timeZoneOffset;      // 時差（時間）
    
public:
    // コンストラクタ
    CAccountManager(bool useAutoLotSize, double riskPercent, double baseLotSize, bool IsPipsX10, int timeZoneOffset = 9);
    
    // デストラクタ
    ~CAccountManager() {};
    
    // ロットサイズ計算
    double CalculateLotSize();
    
    // ゲッターメソッド
    bool GetUseAutoLotSize() { return m_useAutoLotSize; }
    double GetRiskPercent() { return m_riskPercent; }
    double GetBaseLotSize() { return m_baseLotSize; }
    bool GetIsPipsX10() { return m_IsPipsX10; }
    int GetTimeZoneOffset() { return m_timeZoneOffset; }
    
    // 口座情報取得メソッド
    double GetAccountBalance() { return AccountBalance(); }
    double GetAccountEquity() { return AccountEquity(); }
    double GetAccountFreeMargin() { return AccountFreeMargin(); }
    double GetAccountMarginLevel() { return AccountInfoDouble(ACCOUNT_MARGIN_LEVEL); }
    
    // 本日の利益計算メソッド
    double CalculateTodayProfit();
    double CalculateTodayProfitPips();
    bool IsInTodayRange(datetime time);
    
    // 追加メソッド（新規）
    double CalculateMaxLotSize(double stopLossPips);  // 最大ロットサイズ計算
    double GetCurrentDrawdown();                       // 現在のドローダウン
};

//+------------------------------------------------------------------+
//| コンストラクタ                                                     |
//+------------------------------------------------------------------+
CAccountManager::CAccountManager(bool useAutoLotSize, double riskPercent, double baseLotSize, bool IsPipsX10, int timeZoneOffset)
{
    m_useAutoLotSize = useAutoLotSize;
    m_riskPercent = riskPercent;
    m_baseLotSize = baseLotSize;
    m_IsPipsX10 = IsPipsX10;
    m_timeZoneOffset = timeZoneOffset;
}

//+------------------------------------------------------------------+
//| 自動ロットサイズの計算                                             |
//+------------------------------------------------------------------+
double CAccountManager::CalculateLotSize()
{
    // 自動計算が無効の場合は0を返す
    if(!m_useAutoLotSize) return 0.0;
    
    // 証拠金の取得
    double accountBalance = GetAccountBalance();
    
    // リスク額の計算
    double riskAmount = accountBalance * (m_riskPercent / 100.0);
    
    // 100単位で切り捨て
    double roundedRisk = MathFloor(riskAmount / 100) * 100;
    
    // ロットサイズに変換
    double lotSize = roundedRisk / m_baseLotSize;
    
    // ロットサイズの制限
    double minLot = MarketInfo(Symbol(), MODE_MINLOT);
    double maxLot = MarketInfo(Symbol(), MODE_MAXLOT);
    double lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);
    
    // 最小・最大値に調整
    lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
    
    // ロットステップに合わせて調整
    lotSize = MathFloor(lotSize / lotStep) * lotStep;
    
    // 有効数字に正規化
    return NormalizeDouble(lotSize, 2);
}

//+------------------------------------------------------------------+
//| ストップロスを考慮した最大ロットサイズ計算                         |
//+------------------------------------------------------------------+
double CAccountManager::CalculateMaxLotSize(double stopLossPips)
{
    if(stopLossPips <= 0) return 0.0;
    
    double accountBalance = GetAccountBalance();
    double riskAmount = accountBalance * (m_riskPercent / 100.0);
    
    // pips値を調整
    double adjustedPips = m_IsPipsX10 ? stopLossPips * 10 : stopLossPips;
    double pipValue = MarketInfo(Symbol(), MODE_TICKVALUE) * adjustedPips;
    
    if(pipValue <= 0) return 0.0;
    
    double lotSize = riskAmount / pipValue;
    
    // ロットサイズの制限と調整
    double minLot = MarketInfo(Symbol(), MODE_MINLOT);
    double maxLot = MarketInfo(Symbol(), MODE_MAXLOT);
    double lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);
    
    lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
    lotSize = MathFloor(lotSize / lotStep) * lotStep;
    
    return NormalizeDouble(lotSize, 2);
}

//+------------------------------------------------------------------+
//| 本日の利益計算                                                     |
//+------------------------------------------------------------------+
double CAccountManager::CalculateTodayProfit()
{
    double totalProfit = 0.0;
    
    // 決済済み注文の確認
    for(int i = OrdersHistoryTotal() - 1; i >= 0; i--) {
        if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) {
            if(OrderSymbol() == Symbol() && 
               IsInTodayRange(OrderCloseTime()) &&
               OrderProfit() != 0) {  // 実際に損益が発生した注文のみを対象
                totalProfit += OrderProfit() + OrderSwap() + OrderCommission();
            }
        }
    }
    
    // オープンポジションの含み損益も含める
    for(int i = OrdersTotal() - 1; i >= 0; i--) {
        if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
            if(OrderSymbol() == Symbol() && 
               IsInTodayRange(OrderOpenTime())) {
                totalProfit += OrderProfit() + OrderSwap() + OrderCommission();
            }
        }
    }
    
    return totalProfit;
}

//+------------------------------------------------------------------+
//| 本日の利益（pips）計算                                             |
//+------------------------------------------------------------------+
double CAccountManager::CalculateTodayProfitPips()
{
    double totalPips = 0.0;
    
    for(int i = OrdersHistoryTotal() - 1; i >= 0; i--) {
        if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) {
            if(OrderSymbol() == Symbol() && 
               IsInTodayRange(OrderCloseTime()) &&
               OrderProfit() != 0) {  // 実際に損益が発生した注文のみを対象
                double pips = (OrderType() == OP_BUY) ? 
                    (OrderClosePrice() - OrderOpenPrice()) / Point : 
                    (OrderOpenPrice() - OrderClosePrice()) / Point;
                totalPips += pips;
            }
        }
    }
    
    // ブローカーのpips設定に合わせて調整
    if(m_IsPipsX10) totalPips = totalPips / 10;
    
    return totalPips;
}

//+------------------------------------------------------------------+
//| 現在のドローダウン計算                                             |
//+------------------------------------------------------------------+
double CAccountManager::GetCurrentDrawdown()
{
    double balance = GetAccountBalance();
    double equity = GetAccountEquity();
    
    if(balance <= 0) return 0.0;
    
    double drawdown = (balance - equity) / balance * 100.0;
    return drawdown > 0 ? drawdown : 0.0;
}

//+------------------------------------------------------------------+
//| 本日範囲内かどうかを判定                                           |
//+------------------------------------------------------------------+
bool CAccountManager::IsInTodayRange(datetime time)
{
    // 判定対象の時刻に時差を加算
    datetime adjustedTime = time + (m_timeZoneOffset * 3600);
     
    // 現在時刻の日付情報を取得
    datetime currentTime = TimeCurrent();
    currentTime += (m_timeZoneOffset * 3600);
    MqlDateTime currentStruct;
    TimeToStruct(currentTime, currentStruct);
    
    // 本日6:00:00を基準に設定
    currentStruct.hour = 6;
    currentStruct.min = 0;
    currentStruct.sec = 0;
    datetime baseTime = StructToTime(currentStruct);
    
    // 24時間-1秒の範囲を計算
    datetime startTime = baseTime;
    datetime endTime = baseTime + 24 * 3600 - 1;
    
    // 判定対象の時刻が範囲内かどうかを確認
    return (adjustedTime >= startTime && adjustedTime <= endTime);
}
//+------------------------------------------------------------------+