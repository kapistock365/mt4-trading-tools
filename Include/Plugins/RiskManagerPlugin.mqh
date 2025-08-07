//+------------------------------------------------------------------+
//|                                          RiskManagerPlugin.mqh   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property strict

#include "../PluginBase.mqh"

// リスク管理設定
struct RiskSettings {
    double MaxLossPerTrade;        // 1トレードあたり最大損失（%）
    double DailyMaxLoss;          // 1日の最大損失（%）
    bool   UseTrailingStop;       // トレーリングストップ使用
    double TrailingStart;         // トレーリング開始（pips）
    double TrailingDistance;      // トレーリング幅（pips）
    bool   UsePartialClose;       // 部分決済使用
    double PartialCloseProfit;    // 部分決済開始（pips）
    double PartialClosePercent;   // 部分決済割合（%）
    bool   UseBreakEven;          // ブレークイーブン使用
    double BreakEvenProfit;       // ブレークイーブン開始（pips）
    bool   Enabled;               // 有効/無効
};

// リスク管理プラグイン
class CRiskManagerPlugin : public CPluginBase
{
private:
    RiskSettings m_settings;
    datetime m_currentDay;
    double m_dailyStartBalance;
    bool m_dailyLimitReached;
    
public:
    // コンストラクタ
    CRiskManagerPlugin() : 
        CPluginBase("RiskManagerPlugin", "1.0", "自動損切りとリスク管理") {
        
        // デフォルト設定
        m_settings.MaxLossPerTrade = 2.0;
        m_settings.DailyMaxLoss = 5.0;
        m_settings.UseTrailingStop = true;
        m_settings.TrailingStart = 10.0;
        m_settings.TrailingDistance = 5.0;
        m_settings.UsePartialClose = true;
        m_settings.PartialCloseProfit = 10.0;
        m_settings.PartialClosePercent = 50.0;
        m_settings.UseBreakEven = true;
        m_settings.BreakEvenProfit = 5.0;
        m_settings.Enabled = true;
        
        m_currentDay = 0;
        m_dailyStartBalance = 0;
        m_dailyLimitReached = false;
    }
    
    // 初期化
    virtual bool OnInit() override {
        LoadSettings();
        m_dailyStartBalance = AccountBalance();
        m_currentDay = TimeDay(TimeCurrent());
        
        // 既存ポジションに損切り設定
        SetStopLossForAllPositions();
        
        return true;
    }
    
    // 終了処理
    virtual void OnDeinit() override {
        SaveSettings();
    }
    
    // ティック処理
    virtual void OnTick() override {
        if(!m_settings.Enabled) return;
        
        // 日付が変わったらリセット
        if(TimeDay(TimeCurrent()) != m_currentDay) {
            m_currentDay = TimeDay(TimeCurrent());
            m_dailyStartBalance = AccountBalance();
            m_dailyLimitReached = false;
        }
        
        // 日次損失制限チェック
        if(CheckDailyLossLimit()) {
            if(!m_dailyLimitReached) {
                Alert("日次損失制限に到達！");
                m_dailyLimitReached = true;
            }
            return;
        }
        
        // 各ポジションの管理
        ManagePositions();
    }
    
    // 設定パネルの作成
    virtual void CreateSettingsPanel(int &y) override {
        string prefix = "RM_";
        
        CreateLabel(prefix + "Title", "【リスク管理設定】", 10, y);
        y += 20;
        
        CreateCheckbox(prefix + "Enabled", "有効", m_settings.Enabled, 10, y);
        y += 25;
        
        CreateLabel(prefix + "MaxLoss", "最大損失/トレード: " + 
                   DoubleToString(m_settings.MaxLossPerTrade, 1) + "%", 10, y);
        y += 25;
        
        CreateLabel(prefix + "DailyMax", "日次最大損失: " + 
                   DoubleToString(m_settings.DailyMaxLoss, 1) + "%", 10, y);
        y += 25;
        
        CreateCheckbox(prefix + "Trail", "トレーリングストップ", 
                      m_settings.UseTrailingStop, 10, y);
        y += 25;
        
        CreateCheckbox(prefix + "Partial", "部分決済 (" + 
                      DoubleToString(m_settings.PartialClosePercent, 0) + "%)", 
                      m_settings.UsePartialClose, 10, y);
        y += 25;
        
        CreateCheckbox(prefix + "BreakEven", "ブレークイーブン", 
                      m_settings.UseBreakEven, 10, y);
        y += 30;
    }
    
    // チャートイベント処理
    virtual void OnChartEvent(const int id, const long &lparam, 
                            const double &dparam, const string &sparam) override {
        if(id != CHARTEVENT_OBJECT_CLICK) return;
        
        string prefix = "RM_";
        
        if(sparam == prefix + "Enabled") {
            m_settings.Enabled = !m_settings.Enabled;
            UpdateCheckbox(sparam, m_settings.Enabled);
        }
        else if(sparam == prefix + "Trail") {
            m_settings.UseTrailingStop = !m_settings.UseTrailingStop;
            UpdateCheckbox(sparam, m_settings.UseTrailingStop);
        }
        else if(sparam == prefix + "Partial") {
            m_settings.UsePartialClose = !m_settings.UsePartialClose;
            UpdateCheckbox(sparam, m_settings.UsePartialClose);
        }
        else if(sparam == prefix + "BreakEven") {
            m_settings.UseBreakEven = !m_settings.UseBreakEven;
            UpdateCheckbox(sparam, m_settings.UseBreakEven);
        }
    }
    
    // 設定の保存
    virtual bool SaveSettings() override {
        string filename = m_name + ".set";
        int handle = FileOpen(filename, FILE_WRITE|FILE_TXT);
        
        if(handle != INVALID_HANDLE) {
            FileWrite(handle, m_settings.MaxLossPerTrade);
            FileWrite(handle, m_settings.DailyMaxLoss);
            FileWrite(handle, m_settings.UseTrailingStop);
            FileWrite(handle, m_settings.TrailingStart);
            FileWrite(handle, m_settings.TrailingDistance);
            FileWrite(handle, m_settings.UsePartialClose);
            FileWrite(handle, m_settings.PartialCloseProfit);
            FileWrite(handle, m_settings.PartialClosePercent);
            FileWrite(handle, m_settings.UseBreakEven);
            FileWrite(handle, m_settings.BreakEvenProfit);
            FileWrite(handle, m_settings.Enabled);
            FileClose(handle);
            return true;
        }
        
        return false;
    }
    
    // 設定の読み込み
    virtual bool LoadSettings() override {
        // ファイルから読み込み（実装は省略）
        return true;
    }
    
private:
    // ポジション管理
    void ManagePositions() {
        for(int i = OrdersTotal() - 1; i >= 0; i--) {
            if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
                if(OrderSymbol() != Symbol()) continue;
                
                // 損切り設定
                if(OrderStopLoss() == 0) {
                    SetStopLoss(OrderTicket());
                }
                
                double profitPips = CalculateProfitInPips(OrderTicket());
                
                // ブレークイーブン
                if(m_settings.UseBreakEven && profitPips >= m_settings.BreakEvenProfit) {
                    MoveToBreakEven(OrderTicket());
                }
                
                // 部分決済
                if(m_settings.UsePartialClose && profitPips >= m_settings.PartialCloseProfit) {
                    PartialClosePosition(OrderTicket());
                }
                
                // トレーリングストップ
                if(m_settings.UseTrailingStop && profitPips >= m_settings.TrailingStart) {
                    TrailingStop(OrderTicket());
                }
            }
        }
    }
    
    // 損切り設定
    void SetStopLoss(int ticket) {
        if(!OrderSelect(ticket, SELECT_BY_TICKET)) return;
        
        double stopLossDistance = (m_dailyStartBalance * m_settings.MaxLossPerTrade / 100.0) / 
                                 (OrderLots() * MarketInfo(Symbol(), MODE_TICKVALUE));
        stopLossDistance = stopLossDistance * Point;
        
        double stopLoss = 0;
        
        if(OrderType() == OP_BUY) {
            stopLoss = OrderOpenPrice() - stopLossDistance;
        }
        else if(OrderType() == OP_SELL) {
            stopLoss = OrderOpenPrice() + stopLossDistance;
        }
        
        if(stopLoss > 0) {
            OrderModify(ticket, OrderOpenPrice(), stopLoss, OrderTakeProfit(), 0, clrRed);
        }
    }
    
    // 全ポジションに損切り設定
    void SetStopLossForAllPositions() {
        for(int i = 0; i < OrdersTotal(); i++) {
            if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
                if(OrderSymbol() == Symbol() && OrderStopLoss() == 0) {
                    SetStopLoss(OrderTicket());
                }
            }
        }
    }
    
    // その他のヘルパー関数（実装は省略）
    void MoveToBreakEven(int ticket) {}
    void TrailingStop(int ticket) {}
    void PartialClosePosition(int ticket) {}
    double CalculateProfitInPips(int ticket) { return 0; }
    bool CheckDailyLossLimit() { return false; }
    
    // GUI関数（BreakoutPluginと同様）
    void CreateLabel(string name, string text, int x, int y) {
        ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
        ObjectSetString(0, name, OBJPROP_TEXT, text);
        ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
        ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
        ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
    }
    
    void CreateCheckbox(string name, string text, bool checked, int x, int y) {
        string checkMark = checked ? "[✓]" : "[ ]";
        CreateLabel(name, checkMark + " " + text, x, y);
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