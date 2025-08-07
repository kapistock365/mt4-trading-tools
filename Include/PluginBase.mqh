//+------------------------------------------------------------------+
//|                                                  PluginBase.mqh  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property strict

// プラグインの状態
enum ENUM_PLUGIN_STATE {
    PLUGIN_STATE_DISABLED,    // 無効
    PLUGIN_STATE_ENABLED,     // 有効
    PLUGIN_STATE_ERROR        // エラー
};

// プラグインの基底クラス
class CPluginBase
{
protected:
    string m_name;                    // プラグイン名
    string m_version;                 // バージョン
    string m_description;             // 説明
    ENUM_PLUGIN_STATE m_state;       // 状態
    bool m_initialized;               // 初期化済みフラグ

public:
    // コンストラクタ
    CPluginBase(string name, string version, string description) {
        m_name = name;
        m_version = version;
        m_description = description;
        m_state = PLUGIN_STATE_DISABLED;
        m_initialized = false;
    }
    
    // デストラクタ
    virtual ~CPluginBase() {}
    
    // === 必須実装メソッド（派生クラスで実装） ===
    
    // 初期化
    virtual bool OnInit() = 0;
    
    // 終了処理
    virtual void OnDeinit() = 0;
    
    // ティック処理
    virtual void OnTick() = 0;
    
    // === オプション実装メソッド ===
    
    // トレード実行後の処理
    virtual void OnTrade() {}
    
    // タイマー処理
    virtual void OnTimer() {}
    
    // チャートイベント処理
    virtual void OnChartEvent(const int id, const long &lparam, 
                            const double &dparam, const string &sparam) {}
    
    // 設定パネルの作成
    virtual void CreateSettingsPanel(int &y) {}
    
    // 設定の保存
    virtual bool SaveSettings() { return true; }
    
    // 設定の読み込み
    virtual bool LoadSettings() { return true; }
    
    // === 共通メソッド ===
    
    // プラグインの有効化
    bool Enable() {
        if(!m_initialized) {
            if(OnInit()) {
                m_initialized = true;
                m_state = PLUGIN_STATE_ENABLED;
                Print(m_name + " enabled");
                return true;
            } else {
                m_state = PLUGIN_STATE_ERROR;
                Print(m_name + " initialization failed");
                return false;
            }
        }
        m_state = PLUGIN_STATE_ENABLED;
        return true;
    }
    
    // プラグインの無効化
    void Disable() {
        if(m_initialized && m_state == PLUGIN_STATE_ENABLED) {
            OnDeinit();
        }
        m_state = PLUGIN_STATE_DISABLED;
        Print(m_name + " disabled");
    }
    
    // ゲッターメソッド
    string GetName() { return m_name; }
    string GetVersion() { return m_version; }
    string GetDescription() { return m_description; }
    ENUM_PLUGIN_STATE GetState() { return m_state; }
    bool IsEnabled() { return m_state == PLUGIN_STATE_ENABLED; }
};

// プラグインマネージャー
class CPluginManager
{
private:
    CPluginBase* m_plugins[];         // プラグインの配列
    int m_pluginCount;                // プラグイン数

public:
    // コンストラクタ
    CPluginManager() {
        m_pluginCount = 0;
        ArrayResize(m_plugins, 0);
    }
    
    // デストラクタ
    ~CPluginManager() {
        for(int i = 0; i < m_pluginCount; i++) {
            if(m_plugins[i] != NULL) {
                m_plugins[i].Disable();
                delete m_plugins[i];
            }
        }
    }
    
    // プラグインの登録
    bool RegisterPlugin(CPluginBase* plugin) {
        if(plugin == NULL) return false;
        
        ArrayResize(m_plugins, m_pluginCount + 1);
        m_plugins[m_pluginCount] = plugin;
        m_pluginCount++;
        
        Print("Plugin registered: " + plugin.GetName());
        return true;
    }
    
    // 全プラグインの初期化
    void InitializeAll() {
        for(int i = 0; i < m_pluginCount; i++) {
            if(m_plugins[i] != NULL) {
                m_plugins[i].Enable();
            }
        }
    }
    
    // OnTickイベントを全プラグインに伝播
    void OnTick() {
        for(int i = 0; i < m_pluginCount; i++) {
            if(m_plugins[i] != NULL && m_plugins[i].IsEnabled()) {
                m_plugins[i].OnTick();
            }
        }
    }
    
    // OnTradeイベントを全プラグインに伝播
    void OnTrade() {
        for(int i = 0; i < m_pluginCount; i++) {
            if(m_plugins[i] != NULL && m_plugins[i].IsEnabled()) {
                m_plugins[i].OnTrade();
            }
        }
    }
    
    // OnTimerイベントを全プラグインに伝播
    void OnTimer() {
        for(int i = 0; i < m_pluginCount; i++) {
            if(m_plugins[i] != NULL && m_plugins[i].IsEnabled()) {
                m_plugins[i].OnTimer();
            }
        }
    }
    
    // OnChartEventイベントを全プラグインに伝播
    void OnChartEvent(const int id, const long &lparam, 
                      const double &dparam, const string &sparam) {
        for(int i = 0; i < m_pluginCount; i++) {
            if(m_plugins[i] != NULL && m_plugins[i].IsEnabled()) {
                m_plugins[i].OnChartEvent(id, lparam, dparam, sparam);
            }
        }
    }
    
    // プラグインの取得
    CPluginBase* GetPlugin(string name) {
        for(int i = 0; i < m_pluginCount; i++) {
            if(m_plugins[i] != NULL && m_plugins[i].GetName() == name) {
                return m_plugins[i];
            }
        }
        return NULL;
    }
    
    // プラグイン数の取得
    int GetPluginCount() { return m_pluginCount; }
};
//+------------------------------------------------------------------+