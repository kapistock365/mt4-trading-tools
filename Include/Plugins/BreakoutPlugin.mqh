//+------------------------------------------------------------------+
//|                                             BreakoutPlugin.mqh   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property strict

#include "../PluginBase.mqh"
#include "../../CT_Trail_2.00/Include/OrderManager.mqh"

// ブレイクアウトプラグイン設定
struct BreakoutSettings {
    int    LookbackPeriod;        // ブレイクアウト判定期間
    double BreakoutBuffer;        // ブレイクアウトバッファ（pips）
    bool   TradeOnlyWithTrend;    // トレンド方向のみ取引
    int    CooldownMinutes;       // エントリー後のクールダウン
    bool   ShowAlert;             // アラート表示
    bool   Enabled;               // 有効/無効
};

// ブレイクアウトプラグイン
class CBreakoutPlugin : public CPluginBase
{
private:
    BreakoutSettings m_settings;
    COrderManager* m_orderManager;
    datetime m_lastTradeTime;
    double m_lastBreakLevel;
    string m_lastBreakType;
    
public:
    // コンストラクタ
    CBreakoutPlugin(COrderManager* orderManager) : 
        CPluginBase("BreakoutPlugin", "1.0", "ブレイクアウト検出と自動エントリー") {
        
        m_orderManager = orderManager;
        
        // デフォルト設定
        m_settings.LookbackPeriod = 20;
        m_settings.BreakoutBuffer = 2.0;
        m_settings.TradeOnlyWithTrend = true;
        m_settings.CooldownMinutes = 30;
        m_settings.ShowAlert = true;
        m_settings.Enabled = true;
        
        m_lastTradeTime = 0;
        m_lastBreakLevel = 0;
        m_lastBreakType = "";
    }
    
    // 初期化
    virtual bool OnInit() override {
        LoadSettings();
        return true;
    }
    
    // 終了処理
    virtual void OnDeinit() override {
        SaveSettings();
    }
    
    // ティック処理
    virtual void OnTick() override {
        if(!m_settings.Enabled) return;
        
        // クールダウンチェック
        if(TimeCurrent() - m_lastTradeTime < m_settings.CooldownMinutes * 60) {
            return;
        }
        
        CheckBreakout();
    }
    
    // 設定パネルの作成
    virtual void CreateSettingsPanel(int &y) override {
        string prefix = "BP_";
        
        CreateLabel(prefix + "Title", "【ブレイクアウト設定】", 10, y);
        y += 20;
        
        CreateCheckbox(prefix + "Enabled", "有効", m_settings.Enabled, 10, y);
        y += 25;
        
        CreateLabel(prefix + "Period", "判定期間: " + IntegerToString(m_settings.LookbackPeriod), 10, y);
        CreateButton(prefix + "PeriodPlus", "+", 150, y, 30, 20);
        CreateButton(prefix + "PeriodMinus", "-", 185, y, 30, 20);
        y += 25;
        
        CreateLabel(prefix + "Buffer", "バッファ: " + DoubleToString(m_settings.BreakoutBuffer, 1) + " pips", 10, y);
        y += 25;
        
        CreateCheckbox(prefix + "TrendOnly", "トレンド方向のみ", m_settings.TradeOnlyWithTrend, 10, y);
        y += 25;
        
        CreateCheckbox(prefix + "Alert", "アラート表示", m_settings.ShowAlert, 10, y);
        y += 30;
    }
    
    // チャートイベント処理
    virtual void OnChartEvent(const int id, const long &lparam, 
                            const double &dparam, const string &sparam) override {
        if(id != CHARTEVENT_OBJECT_CLICK) return;
        
        string prefix = "BP_";
        
        if(sparam == prefix + "Enabled") {
            m_settings.Enabled = !m_settings.Enabled;
            UpdateCheckbox(sparam, m_settings.Enabled);
        }
        else if(sparam == prefix + "PeriodPlus") {
            m_settings.LookbackPeriod = MathMin(50, m_settings.LookbackPeriod + 5);
            UpdateLabel(prefix + "Period", "判定期間: " + IntegerToString(m_settings.LookbackPeriod));
        }
        else if(sparam == prefix + "PeriodMinus") {
            m_settings.LookbackPeriod = MathMax(10, m_settings.LookbackPeriod - 5);
            UpdateLabel(prefix + "Period", "判定期間: " + IntegerToString(m_settings.LookbackPeriod));
        }
        else if(sparam == prefix + "TrendOnly") {
            m_settings.TradeOnlyWithTrend = !m_settings.TradeOnlyWithTrend;
            UpdateCheckbox(sparam, m_settings.TradeOnlyWithTrend);
        }
        else if(sparam == prefix + "Alert") {
            m_settings.ShowAlert = !m_settings.ShowAlert;
            UpdateCheckbox(sparam, m_settings.ShowAlert);
        }
    }
    
    // 設定の保存
    virtual bool SaveSettings() override {
        string filename = m_name + ".set";
        int handle = FileOpen(filename, FILE_WRITE|FILE_TXT);
        
        if(handle != INVALID_HANDLE) {
            FileWrite(handle, m_settings.LookbackPeriod);
            FileWrite(handle, m_settings.BreakoutBuffer);
            FileWrite(handle, m_settings.TradeOnlyWithTrend);
            FileWrite(handle, m_settings.CooldownMinutes);
            FileWrite(handle, m_settings.ShowAlert);
            FileWrite(handle, m_settings.Enabled);
            FileClose(handle);
            return true;
        }
        
        return false;
    }
    
    // 設定の読み込み
    virtual bool LoadSettings() override {
        string filename = m_name + ".set";
        int handle = FileOpen(filename, FILE_READ|FILE_TXT);
        
        if(handle != INVALID_HANDLE) {
            m_settings.LookbackPeriod = (int)StringToInteger(FileReadString(handle));
            m_settings.BreakoutBuffer = StringToDouble(FileReadString(handle));
            m_settings.TradeOnlyWithTrend = (bool)StringToInteger(FileReadString(handle));
            m_settings.CooldownMinutes = (int)StringToInteger(FileReadString(handle));
            m_settings.ShowAlert = (bool)StringToInteger(FileReadString(handle));
            m_settings.Enabled = (bool)StringToInteger(FileReadString(handle));
            FileClose(handle);
            return true;
        }
        
        return false;
    }
    
private:
    // ブレイクアウトチェック
    void CheckBreakout() {
        // サポート・レジスタンスレベルの計算
        double support = Low[iLowest(NULL, 0, MODE_LOW, m_settings.LookbackPeriod, 1)];
        double resistance = High[iHighest(NULL, 0, MODE_HIGH, m_settings.LookbackPeriod, 1)];
        double bufferSize = m_settings.BreakoutBuffer * Point * 10;
        
        // トレンド判定
        string currentTrend = GetCurrentTrend();
        
        // 上昇ブレイクアウト
        if(Close[0] > resistance + bufferSize && Close[1] <= resistance + bufferSize) {
            if(!m_settings.TradeOnlyWithTrend || currentTrend == "UPTREND") {
                if(m_lastBreakType != "BULLISH" || MathAbs(resistance - m_lastBreakLevel) > 10 * Point) {
                    if(m_settings.ShowAlert) {
                        Alert("上昇ブレイクアウト検出: ", resistance);
                    }
                    
                    if(m_orderManager != NULL && m_orderManager.PlaceBuyOrder(true)) {
                        m_lastTradeTime = TimeCurrent();
                        m_lastBreakType = "BULLISH";
                        m_lastBreakLevel = resistance;
                    }
                }
            }
        }
        
        // 下降ブレイクアウト
        if(Close[0] < support - bufferSize && Close[1] >= support - bufferSize) {
            if(!m_settings.TradeOnlyWithTrend || currentTrend == "DOWNTREND") {
                if(m_lastBreakType != "BEARISH" || MathAbs(support - m_lastBreakLevel) > 10 * Point) {
                    if(m_settings.ShowAlert) {
                        Alert("下降ブレイクアウト検出: ", support);
                    }
                    
                    if(m_orderManager != NULL && m_orderManager.PlaceSellOrder(true)) {
                        m_lastTradeTime = TimeCurrent();
                        m_lastBreakType = "BEARISH";
                        m_lastBreakLevel = support;
                    }
                }
            }
        }
    }
    
    // トレンド判定
    string GetCurrentTrend() {
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
    
    // GUI作成ヘルパー関数
    void CreateLabel(string name, string text, int x, int y) {
        ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
        ObjectSetString(0, name, OBJPROP_TEXT, text);
        ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
        ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
        ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
    }
    
    void CreateButton(string name, string text, int x, int y, int width, int height) {
        ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
        ObjectSetString(0, name, OBJPROP_TEXT, text);
        ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
        ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
        ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
        ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
        ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    }
    
    void CreateCheckbox(string name, string text, bool checked, int x, int y) {
        string checkMark = checked ? "[✓]" : "[ ]";
        CreateLabel(name, checkMark + " " + text, x, y);
    }
    
    void UpdateLabel(string name, string text) {
        ObjectSetString(0, name, OBJPROP_TEXT, text);
    }
    
    void UpdateCheckbox(string name, bool checked) {
        string currentText = ObjectGetString(0, name, OBJPROP_TEXT);
        int spacePos = StringFind(currentText, " ", 3);
        if(spacePos > 0) {
            string labelText = StringSubstr(currentText, spacePos);
            string checkMark = checked ? "[✓]" : "[ ]";
            ObjectSetString(0, name, OBJPROP_TEXT, checkMark + labelText);
        }
    }
};
//+------------------------------------------------------------------+