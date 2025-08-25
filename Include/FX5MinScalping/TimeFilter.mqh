//+------------------------------------------------------------------+
//|                                                   TimeFilter.mqh |
//|                               時間帯フィルターモジュール          |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, FX5MinScalping"
#property link      "https://github.com/kapistock365/mt4-trading-tools"
#property strict

//+------------------------------------------------------------------+
//| セッション定義                                                   |
//+------------------------------------------------------------------+
enum ENUM_TRADING_SESSION {
    SESSION_NONE = 0,        // セッション外
    SESSION_ASIAN = 1,       // アジアセッション
    SESSION_LONDON = 2,      // ロンドンセッション
    SESSION_NEWYORK = 4,     // ニューヨークセッション
    SESSION_OVERLAP = 6      // ロンドン・NYオーバーラップ
};

//+------------------------------------------------------------------+
//| 時間帯フィルタークラス                                           |
//+------------------------------------------------------------------+
class CTimeFilter {
private:
    // 設定パラメータ
    struct Settings {
        bool enabled;                   // フィルター有効/無効
        int startHour;                  // 取引開始時間（サーバー時間）
        int startMinute;                // 取引開始分
        int endHour;                    // 取引終了時間
        int endMinute;                  // 取引終了分
        bool tradeLondon;               // ロンドンセッション取引
        bool tradeNewYork;              // NYセッション取引
        bool tradeAsian;                // アジアセッション取引
        bool tradeOverlap;              // オーバーラップ優先
        bool avoidMonday;               // 月曜日回避
        bool avoidFriday;               // 金曜日回避
        int fridayCloseHour;            // 金曜日終了時間
        bool avoidNewsTime;             // ニュース時間回避
        int newsBufferMinutes;          // ニュースバッファ（分）
        int gmtOffset;                  // GMTオフセット
    } m_settings;
    
    // セッション時間（GMT基準）
    struct SessionTime {
        int startHour;
        int startMinute;
        int endHour;
        int endMinute;
    };
    
    SessionTime m_asianSession;
    SessionTime m_londonSession;
    SessionTime m_nySession;
    
    // 内部変数
    datetime m_lastUpdateTime;
    ENUM_TRADING_SESSION m_currentSession;
    bool m_isOptimalTime;
    string m_restrictionReason;
    
    // 重要経済指標時間（簡易版）
    struct NewsEvent {
        int dayOfWeek;
        int hour;
        int minute;
        string currency;
        string eventName;
        int impact; // 1:Low, 2:Medium, 3:High
    };
    
    NewsEvent m_newsEvents[20];
    int m_newsEventCount;
    
public:
    //+------------------------------------------------------------------+
    //| コンストラクタ                                                   |
    //+------------------------------------------------------------------+
    CTimeFilter() {
        InitializeSettings();
        InitializeSessionTimes();
        InitializeNewsEvents();
        m_lastUpdateTime = 0;
        m_currentSession = SESSION_NONE;
        m_isOptimalTime = false;
        m_restrictionReason = "";
    }
    
    //+------------------------------------------------------------------+
    //| 初期化                                                           |
    //+------------------------------------------------------------------+
    bool Initialize(bool enabled = true,
                   int startHour = 0,
                   int startMinute = 0,
                   int endHour = 23,
                   int endMinute = 59,
                   bool tradeLondon = true,
                   bool tradeNewYork = true,
                   bool tradeAsian = false,
                   bool tradeOverlap = true,
                   bool avoidMonday = false,
                   bool avoidFriday = false,
                   int fridayCloseHour = 20,
                   bool avoidNewsTime = true,
                   int newsBufferMinutes = 30,
                   int gmtOffset = 0) {
        
        m_settings.enabled = enabled;
        m_settings.startHour = startHour;
        m_settings.startMinute = startMinute;
        m_settings.endHour = endHour;
        m_settings.endMinute = endMinute;
        m_settings.tradeLondon = tradeLondon;
        m_settings.tradeNewYork = tradeNewYork;
        m_settings.tradeAsian = tradeAsian;
        m_settings.tradeOverlap = tradeOverlap;
        m_settings.avoidMonday = avoidMonday;
        m_settings.avoidFriday = avoidFriday;
        m_settings.fridayCloseHour = fridayCloseHour;
        m_settings.avoidNewsTime = avoidNewsTime;
        m_settings.newsBufferMinutes = newsBufferMinutes;
        m_settings.gmtOffset = gmtOffset;
        
        UpdateStatus();
        
        Print("TimeFilter initialized successfully");
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| 取引可能時間チェック                                             |
    //+------------------------------------------------------------------+
    bool IsTradingAllowed() {
        if(!m_settings.enabled) return true;
        
        UpdateStatus();
        return m_isOptimalTime;
    }
    
    //+------------------------------------------------------------------+
    //| 現在のセッション取得                                             |
    //+------------------------------------------------------------------+
    ENUM_TRADING_SESSION GetCurrentSession() {
        UpdateStatus();
        return m_currentSession;
    }
    
    //+------------------------------------------------------------------+
    //| セッション名取得                                                 |
    //+------------------------------------------------------------------+
    string GetSessionName() {
        switch(m_currentSession) {
            case SESSION_ASIAN:    return "Asian";
            case SESSION_LONDON:   return "London";
            case SESSION_NEWYORK:  return "New York";
            case SESSION_OVERLAP:  return "London-NY Overlap";
            default:              return "No Session";
        }
    }
    
    //+------------------------------------------------------------------+
    //| 制限理由取得                                                     |
    //+------------------------------------------------------------------+
    string GetRestrictionReason() {
        return m_restrictionReason;
    }
    
    //+------------------------------------------------------------------+
    //| 次のセッション開始時間取得                                       |
    //+------------------------------------------------------------------+
    datetime GetNextSessionStart() {
        datetime currentTime = TimeCurrent();
        MqlDateTime dt;
        TimeToStruct(currentTime, dt);
        
        // 現在のGMT時間計算
        int gmtHour = (dt.hour - m_settings.gmtOffset + 24) % 24;
        
        // 次のセッション検索
        int nextHour = 24;
        string nextSession = "";
        
        // アジアセッション
        if(m_settings.tradeAsian) {
            int asianStart = m_asianSession.startHour;
            if(gmtHour < asianStart) {
                if(asianStart < nextHour) {
                    nextHour = asianStart;
                    nextSession = "Asian";
                }
            }
        }
        
        // ロンドンセッション
        if(m_settings.tradeLondon) {
            int londonStart = m_londonSession.startHour;
            if(gmtHour < londonStart) {
                if(londonStart < nextHour) {
                    nextHour = londonStart;
                    nextSession = "London";
                }
            }
        }
        
        // NYセッション
        if(m_settings.tradeNewYork) {
            int nyStart = m_nySession.startHour;
            if(gmtHour < nyStart) {
                if(nyStart < nextHour) {
                    nextHour = nyStart;
                    nextSession = "New York";
                }
            }
        }
        
        // 次の日の最初のセッション
        if(nextHour == 24) {
            if(m_settings.tradeAsian) nextHour = m_asianSession.startHour;
            else if(m_settings.tradeLondon) nextHour = m_londonSession.startHour;
            else if(m_settings.tradeNewYork) nextHour = m_nySession.startHour;
        }
        
        // サーバー時間に変換
        int serverHour = (nextHour + m_settings.gmtOffset) % 24;
        dt.hour = serverHour;
        dt.min = 0;
        dt.sec = 0;
        
        return StructToTime(dt);
    }
    
    //+------------------------------------------------------------------+
    //| セッション残り時間取得（分）                                     |
    //+------------------------------------------------------------------+
    int GetSessionRemainingMinutes() {
        if(m_currentSession == SESSION_NONE) return 0;
        
        datetime currentTime = TimeCurrent();
        MqlDateTime dt;
        TimeToStruct(currentTime, dt);
        
        int currentMinutes = dt.hour * 60 + dt.min;
        int endMinutes = 0;
        
        // 現在のセッション終了時間取得
        switch(m_currentSession) {
            case SESSION_ASIAN:
                endMinutes = (m_asianSession.endHour + m_settings.gmtOffset) * 60 + 
                           m_asianSession.endMinute;
                break;
            case SESSION_LONDON:
                endMinutes = (m_londonSession.endHour + m_settings.gmtOffset) * 60 + 
                           m_londonSession.endMinute;
                break;
            case SESSION_NEWYORK:
                endMinutes = (m_nySession.endHour + m_settings.gmtOffset) * 60 + 
                           m_nySession.endMinute;
                break;
            case SESSION_OVERLAP:
                endMinutes = (m_londonSession.endHour + m_settings.gmtOffset) * 60 + 
                           m_londonSession.endMinute;
                break;
        }
        
        int remaining = endMinutes - currentMinutes;
        if(remaining < 0) remaining += 24 * 60;
        
        return remaining;
    }
    
    //+------------------------------------------------------------------+
    //| 統計情報取得                                                     |
    //+------------------------------------------------------------------+
    void GetStatistics(string &stats[]) {
        ArrayResize(stats, 8);
        
        stats[0] = "=== Time Filter Status ===";
        stats[1] = "Enabled: " + (m_settings.enabled ? "Yes" : "No");
        stats[2] = "Current Session: " + GetSessionName();
        stats[3] = "Trading Allowed: " + (m_isOptimalTime ? "Yes" : "No");
        
        if(!m_isOptimalTime && m_restrictionReason != "") {
            stats[4] = "Restriction: " + m_restrictionReason;
        } else {
            stats[4] = "Session Remaining: " + IntegerToString(GetSessionRemainingMinutes()) + " min";
        }
        
        stats[5] = "GMT Offset: " + IntegerToString(m_settings.gmtOffset);
        stats[6] = "News Filter: " + (m_settings.avoidNewsTime ? "Active" : "Inactive");
        stats[7] = "Next Session: " + TimeToString(GetNextSessionStart(), TIME_MINUTES);
    }
    
private:
    //+------------------------------------------------------------------+
    //| 設定初期化                                                       |
    //+------------------------------------------------------------------+
    void InitializeSettings() {
        m_settings.enabled = false;
        m_settings.startHour = 0;
        m_settings.startMinute = 0;
        m_settings.endHour = 23;
        m_settings.endMinute = 59;
        m_settings.tradeLondon = true;
        m_settings.tradeNewYork = true;
        m_settings.tradeAsian = false;
        m_settings.tradeOverlap = true;
        m_settings.avoidMonday = false;
        m_settings.avoidFriday = false;
        m_settings.fridayCloseHour = 20;
        m_settings.avoidNewsTime = true;
        m_settings.newsBufferMinutes = 30;
        m_settings.gmtOffset = 0;
    }
    
    //+------------------------------------------------------------------+
    //| セッション時間初期化（GMT基準）                                  |
    //+------------------------------------------------------------------+
    void InitializeSessionTimes() {
        // アジアセッション（東京）: GMT 00:00 - 09:00
        m_asianSession.startHour = 0;
        m_asianSession.startMinute = 0;
        m_asianSession.endHour = 9;
        m_asianSession.endMinute = 0;
        
        // ロンドンセッション: GMT 07:00 - 16:00（夏時間）
        m_londonSession.startHour = 7;
        m_londonSession.startMinute = 0;
        m_londonSession.endHour = 16;
        m_londonSession.endMinute = 0;
        
        // ニューヨークセッション: GMT 12:00 - 21:00（夏時間）
        m_nySession.startHour = 12;
        m_nySession.startMinute = 0;
        m_nySession.endHour = 21;
        m_nySession.endMinute = 0;
    }
    
    //+------------------------------------------------------------------+
    //| ニュースイベント初期化（簡易版）                                 |
    //+------------------------------------------------------------------+
    void InitializeNewsEvents() {
        m_newsEventCount = 0;
        
        // 主要な定期イベント（例）
        // NFP（第1金曜日）
        AddNewsEvent(5, 12, 30, "USD", "Non-Farm Payrolls", 3);
        
        // ECB政策金利（木曜日）
        AddNewsEvent(4, 11, 45, "EUR", "ECB Rate Decision", 3);
        
        // FOMC（水曜日）
        AddNewsEvent(3, 18, 0, "USD", "FOMC Statement", 3);
        
        // UK GDP（金曜日）
        AddNewsEvent(5, 8, 30, "GBP", "UK GDP", 2);
    }
    
    //+------------------------------------------------------------------+
    //| ニュースイベント追加                                             |
    //+------------------------------------------------------------------+
    void AddNewsEvent(int dayOfWeek, int hour, int minute, 
                     string currency, string eventName, int impact) {
        if(m_newsEventCount >= 20) return;
        
        m_newsEvents[m_newsEventCount].dayOfWeek = dayOfWeek;
        m_newsEvents[m_newsEventCount].hour = hour;
        m_newsEvents[m_newsEventCount].minute = minute;
        m_newsEvents[m_newsEventCount].currency = currency;
        m_newsEvents[m_newsEventCount].eventName = eventName;
        m_newsEvents[m_newsEventCount].impact = impact;
        
        m_newsEventCount++;
    }
    
    //+------------------------------------------------------------------+
    //| 状態更新                                                         |
    //+------------------------------------------------------------------+
    void UpdateStatus() {
        datetime currentTime = TimeCurrent();
        
        // 1分ごとに更新
        if(currentTime - m_lastUpdateTime < 60) return;
        m_lastUpdateTime = currentTime;
        
        MqlDateTime dt;
        TimeToStruct(currentTime, dt);
        
        // 基本時間チェック
        m_isOptimalTime = CheckBasicTimeFilter(dt);
        
        if(m_isOptimalTime) {
            // セッションチェック
            m_currentSession = GetActiveSession(dt);
            m_isOptimalTime = CheckSessionFilter(m_currentSession);
            
            // 曜日チェック
            if(m_isOptimalTime) {
                m_isOptimalTime = CheckDayFilter(dt);
            }
            
            // ニュースチェック
            if(m_isOptimalTime && m_settings.avoidNewsTime) {
                m_isOptimalTime = CheckNewsFilter(dt);
            }
        }
    }
    
    //+------------------------------------------------------------------+
    //| 基本時間フィルターチェック                                       |
    //+------------------------------------------------------------------+
    bool CheckBasicTimeFilter(MqlDateTime &dt) {
        int currentMinutes = dt.hour * 60 + dt.min;
        int startMinutes = m_settings.startHour * 60 + m_settings.startMinute;
        int endMinutes = m_settings.endHour * 60 + m_settings.endMinute;
        
        if(startMinutes <= endMinutes) {
            // 同日内の時間範囲
            if(currentMinutes < startMinutes || currentMinutes > endMinutes) {
                m_restrictionReason = "Outside trading hours";
                return false;
            }
        } else {
            // 日をまたぐ時間範囲
            if(currentMinutes < startMinutes && currentMinutes > endMinutes) {
                m_restrictionReason = "Outside trading hours";
                return false;
            }
        }
        
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| アクティブセッション取得                                         |
    //+------------------------------------------------------------------+
    ENUM_TRADING_SESSION GetActiveSession(MqlDateTime &dt) {
        // GMT時間に変換
        int gmtHour = (dt.hour - m_settings.gmtOffset + 24) % 24;
        int gmtMinutes = gmtHour * 60 + dt.min;
        
        bool isAsian = false;
        bool isLondon = false;
        bool isNewYork = false;
        
        // アジアセッション判定
        int asianStart = m_asianSession.startHour * 60 + m_asianSession.startMinute;
        int asianEnd = m_asianSession.endHour * 60 + m_asianSession.endMinute;
        if(gmtMinutes >= asianStart && gmtMinutes < asianEnd) {
            isAsian = true;
        }
        
        // ロンドンセッション判定
        int londonStart = m_londonSession.startHour * 60 + m_londonSession.startMinute;
        int londonEnd = m_londonSession.endHour * 60 + m_londonSession.endMinute;
        if(gmtMinutes >= londonStart && gmtMinutes < londonEnd) {
            isLondon = true;
        }
        
        // NYセッション判定
        int nyStart = m_nySession.startHour * 60 + m_nySession.startMinute;
        int nyEnd = m_nySession.endHour * 60 + m_nySession.endMinute;
        if(gmtMinutes >= nyStart && gmtMinutes < nyEnd) {
            isNewYork = true;
        }
        
        // オーバーラップ判定
        if(isLondon && isNewYork) {
            return SESSION_OVERLAP;
        } else if(isLondon) {
            return SESSION_LONDON;
        } else if(isNewYork) {
            return SESSION_NEWYORK;
        } else if(isAsian) {
            return SESSION_ASIAN;
        }
        
        return SESSION_NONE;
    }
    
    //+------------------------------------------------------------------+
    //| セッションフィルターチェック                                     |
    //+------------------------------------------------------------------+
    bool CheckSessionFilter(ENUM_TRADING_SESSION session) {
        switch(session) {
            case SESSION_ASIAN:
                if(!m_settings.tradeAsian) {
                    m_restrictionReason = "Asian session not allowed";
                    return false;
                }
                break;
                
            case SESSION_LONDON:
                if(!m_settings.tradeLondon) {
                    m_restrictionReason = "London session not allowed";
                    return false;
                }
                break;
                
            case SESSION_NEWYORK:
                if(!m_settings.tradeNewYork) {
                    m_restrictionReason = "NY session not allowed";
                    return false;
                }
                break;
                
            case SESSION_OVERLAP:
                // オーバーラップは常に最優先
                return true;
                
            case SESSION_NONE:
                m_restrictionReason = "No active session";
                return false;
        }
        
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| 曜日フィルターチェック                                           |
    //+------------------------------------------------------------------+
    bool CheckDayFilter(MqlDateTime &dt) {
        // 月曜日チェック
        if(m_settings.avoidMonday && dt.day_of_week == 1) {
            m_restrictionReason = "Monday trading not allowed";
            return false;
        }
        
        // 金曜日チェック
        if(m_settings.avoidFriday && dt.day_of_week == 5) {
            if(dt.hour >= m_settings.fridayCloseHour) {
                m_restrictionReason = "Friday late hours not allowed";
                return false;
            }
        }
        
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| ニュースフィルターチェック                                       |
    //+------------------------------------------------------------------+
    bool CheckNewsFilter(MqlDateTime &dt) {
        int currentMinutes = dt.hour * 60 + dt.min;
        
        for(int i = 0; i < m_newsEventCount; i++) {
            // 曜日チェック
            if(dt.day_of_week != m_newsEvents[i].dayOfWeek) continue;
            
            // 高インパクトニュースのみフィルター
            if(m_newsEvents[i].impact < 2) continue;
            
            // GMT時間に変換
            int newsMinutes = (m_newsEvents[i].hour + m_settings.gmtOffset) * 60 + 
                            m_newsEvents[i].minute;
            
            // バッファ時間チェック
            int timeDiff = MathAbs(currentMinutes - newsMinutes);
            if(timeDiff <= m_settings.newsBufferMinutes) {
                m_restrictionReason = "Near news event: " + m_newsEvents[i].eventName;
                return false;
            }
        }
        
        return true;
    }
};

//+------------------------------------------------------------------+