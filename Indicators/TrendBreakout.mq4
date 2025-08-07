//+------------------------------------------------------------------+
//|                                              TrendBreakout.mq4   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property link      ""
#property version   "1.00"
#property strict
#property indicator_chart_window
#property indicator_buffers 4
#property indicator_color1 clrDodgerBlue    // サポートライン
#property indicator_color2 clrCrimson       // レジスタンスライン
#property indicator_color3 clrLime          // 上昇ブレイクアウト
#property indicator_color4 clrRed           // 下降ブレイクアウト
#property indicator_width1 2
#property indicator_width2 2
#property indicator_width3 3
#property indicator_width4 3

// インプットパラメータ
input int    LookbackPeriod = 20;          // 高値安値を探す期間
input double BreakoutBuffer = 2.0;         // ブレイクアウト判定バッファ（pips）
input bool   ShowAlert = true;             // アラート表示
input bool   SendNotification = false;     // プッシュ通知
input int    TrendPeriod = 50;             // トレンド判定期間
input bool   ShowTrendInfo = true;         // トレンド情報を表示

// バッファ
double SupportBuffer[];
double ResistanceBuffer[];
double BullishBreakBuffer[];
double BearishBreakBuffer[];

// グローバル変数
double lastSupport = 0;
double lastResistance = 0;
datetime lastAlertTime = 0;
string lastAlertType = "";

//+------------------------------------------------------------------+
//| カスタムインジケーター初期化関数                                 |
//+------------------------------------------------------------------+
int OnInit()
{
    // インジケーターバッファの設定
    SetIndexBuffer(0, SupportBuffer);
    SetIndexBuffer(1, ResistanceBuffer);
    SetIndexBuffer(2, BullishBreakBuffer);
    SetIndexBuffer(3, BearishBreakBuffer);
    
    SetIndexStyle(0, DRAW_LINE);
    SetIndexStyle(1, DRAW_LINE);
    SetIndexStyle(2, DRAW_ARROW);
    SetIndexStyle(3, DRAW_ARROW);
    
    SetIndexArrow(2, 233);  // 上向き矢印
    SetIndexArrow(3, 234);  // 下向き矢印
    
    SetIndexLabel(0, "Support");
    SetIndexLabel(1, "Resistance");
    SetIndexLabel(2, "Bullish Break");
    SetIndexLabel(3, "Bearish Break");
    
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
    int limit = rates_total - prev_calculated;
    if(prev_calculated > 0) limit++;
    
    // 最低限必要なバー数のチェック
    if(rates_total < LookbackPeriod + TrendPeriod)
        return(0);
    
    for(int i = MathMin(limit, rates_total - LookbackPeriod - 1); i >= 0; i--)
    {
        // サポート・レジスタンスレベルの計算
        double support = Low[iLowest(NULL, 0, MODE_LOW, LookbackPeriod, i)];
        double resistance = High[iHighest(NULL, 0, MODE_HIGH, LookbackPeriod, i)];
        
        SupportBuffer[i] = support;
        ResistanceBuffer[i] = resistance;
        
        // ブレイクアウトの検出
        double bufferSize = BreakoutBuffer * Point * 10;  // pipsをポイントに変換
        
        // 上昇ブレイクアウト
        if(Close[i] > resistance + bufferSize && Close[i+1] <= resistance + bufferSize)
        {
            BullishBreakBuffer[i] = Low[i] - 10 * Point;
            if(i == 0 && ShowAlert) AlertBreakout("BULLISH", resistance);
        }
        else
        {
            BullishBreakBuffer[i] = EMPTY_VALUE;
        }
        
        // 下降ブレイクアウト
        if(Close[i] < support - bufferSize && Close[i+1] >= support - bufferSize)
        {
            BearishBreakBuffer[i] = High[i] + 10 * Point;
            if(i == 0 && ShowAlert) AlertBreakout("BEARISH", support);
        }
        else
        {
            BearishBreakBuffer[i] = EMPTY_VALUE;
        }
    }
    
    // トレンド情報の表示
    if(ShowTrendInfo && rates_total > 0)
    {
        DisplayTrendInfo();
    }
    
    return(rates_total);
}

//+------------------------------------------------------------------+
//| ブレイクアウトアラート                                           |
//+------------------------------------------------------------------+
void AlertBreakout(string type, double level)
{
    // 同じアラートを連続で出さないようにする
    if(TimeCurrent() - lastAlertTime < 60) return;  // 1分間のクールダウン
    if(lastAlertType == type && MathAbs(level - (type == "BULLISH" ? lastResistance : lastSupport)) < Point) return;
    
    string message = StringFormat("%s ブレイクアウト検出！ %s @ %.5f", 
                                 type, Symbol(), level);
    
    Alert(message);
    
    if(SendNotification)
    {
        SendNotification(message);
    }
    
    lastAlertTime = TimeCurrent();
    lastAlertType = type;
    if(type == "BULLISH") lastResistance = level;
    else lastSupport = level;
}

//+------------------------------------------------------------------+
//| トレンド情報を表示                                               |
//+------------------------------------------------------------------+
void DisplayTrendInfo()
{
    // 移動平均を使ったトレンド判定
    double ma20 = iMA(NULL, 0, 20, 0, MODE_SMA, PRICE_CLOSE, 0);
    double ma50 = iMA(NULL, 0, TrendPeriod, 0, MODE_SMA, PRICE_CLOSE, 0);
    
    string trend = "NEUTRAL";
    color trendColor = clrGray;
    
    if(ma20 > ma50 && Close[0] > ma20)
    {
        trend = "UPTREND";
        trendColor = clrLime;
    }
    else if(ma20 < ma50 && Close[0] < ma20)
    {
        trend = "DOWNTREND";
        trendColor = clrRed;
    }
    
    // トレンド強度の計算（ADX）
    double adx = iADX(NULL, 0, 14, PRICE_CLOSE, MODE_MAIN, 0);
    string strength = "弱い";
    if(adx > 25) strength = "中程度";
    if(adx > 40) strength = "強い";
    
    // 情報表示
    string info = StringFormat("トレンド: %s | 強度: %s (ADX: %.1f)", 
                              trend, strength, adx);
    
    Comment(info);
    
    // ラベルでの表示
    string labelName = "TrendInfo";
    if(ObjectFind(0, labelName) < 0)
    {
        ObjectCreate(0, labelName, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, labelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, labelName, OBJPROP_XDISTANCE, 10);
        ObjectSetInteger(0, labelName, OBJPROP_YDISTANCE, 30);
    }
    
    ObjectSetString(0, labelName, OBJPROP_TEXT, info);
    ObjectSetInteger(0, labelName, OBJPROP_COLOR, trendColor);
    ObjectSetString(0, labelName, OBJPROP_FONT, "Arial Bold");
    ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 12);
}

//+------------------------------------------------------------------+
//| インジケーター終了時の処理                                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Comment("");
    ObjectDelete(0, "TrendInfo");
}
//+------------------------------------------------------------------+