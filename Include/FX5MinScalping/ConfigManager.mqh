//+------------------------------------------------------------------+
//|                                              ConfigManager.mqh  |
//|                               設定ファイル管理モジュール         |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, FX5MinScalping"
#property link      "https://github.com/kapistock365/mt4-trading-tools"
#property strict

//+------------------------------------------------------------------+
//| 設定プロファイル構造体                                           |
//+------------------------------------------------------------------+
struct ConfigProfile {
    string profileName;                 // プロファイル名
    string description;                 // 説明
    datetime createdDate;               // 作成日時
    datetime modifiedDate;              // 更新日時
    
    // 基本設定
    double riskPercent;
    double defaultLots;
    bool useAutoLot;
    
    // 戦略設定
    bool enablePatternBreak;
    bool enablePBPullback;
    bool enablePBCombo;
    
    // パターンブレイク設定
    int minBuildupBars;
    int maxBuildupBars;
    double buildupRangePips;
    double breakoutMinPips;
    double breakoutMaxPips;
    int confirmationBars;
    
    // エントリー/エグジット設定
    double stopLossPips;
    double takeProfitPips;
    bool useTrailingStop;
    double trailingStartPips;
    double trailingStepPips;
    bool useBreakEven;
    double breakEvenTrigger;
    
    // フィルター設定
    double maxEMADistance;
    double maxSpreadPips;
    bool useTimeFilter;
    int startHour;
    int endHour;
    
    // リスク管理
    int maxTradesPerDay;
    double maxDailyLoss;
    int cooldownMinutes;
    int maxConcurrentTrades;
};

//+------------------------------------------------------------------+
//| 設定管理クラス                                                   |
//+------------------------------------------------------------------+
class CConfigManager {
private:
    string m_configPath;                // 設定ファイルパス
    string m_profilesPath;              // プロファイルフォルダパス
    ConfigProfile m_currentProfile;     // 現在のプロファイル
    ConfigProfile m_defaultProfile;     // デフォルトプロファイル
    string m_lastError;                 // 最後のエラー
    
    // プリセットプロファイル
    ConfigProfile m_safeProfile;        // 安全設定
    ConfigProfile m_balancedProfile;    // バランス設定
    ConfigProfile m_aggressiveProfile;  // アグレッシブ設定
    
public:
    //+------------------------------------------------------------------+
    //| コンストラクタ                                                   |
    //+------------------------------------------------------------------+
    CConfigManager() {
        m_configPath = "FX5MinScalping\\";
        m_profilesPath = m_configPath + "Profiles\\";
        m_lastError = "";
        
        InitializeDefaultProfile();
        InitializePresetProfiles();
        m_currentProfile = m_defaultProfile;
    }
    
    //+------------------------------------------------------------------+
    //| プロファイル保存                                                 |
    //+------------------------------------------------------------------+
    bool SaveProfile(string profileName, string description = "") {
        if(profileName == "") {
            m_lastError = "Profile name cannot be empty";
            return false;
        }
        
        // プロファイル更新
        m_currentProfile.profileName = profileName;
        m_currentProfile.description = description;
        m_currentProfile.modifiedDate = TimeCurrent();
        
        // ファイルパス作成
        string filename = m_profilesPath + profileName + ".conf";
        
        // ファイル書き込み
        int handle = FileOpen(filename, FILE_WRITE|FILE_TXT);
        if(handle == INVALID_HANDLE) {
            m_lastError = "Failed to create profile file: " + filename;
            return false;
        }
        
        // ヘッダー情報
        FileWriteString(handle, "# FX 5-Minute Scalping EA Configuration Profile\n");
        FileWriteString(handle, "# Profile: " + profileName + "\n");
        FileWriteString(handle, "# Description: " + description + "\n");
        FileWriteString(handle, "# Created: " + TimeToString(m_currentProfile.createdDate) + "\n");
        FileWriteString(handle, "# Modified: " + TimeToString(m_currentProfile.modifiedDate) + "\n");
        FileWriteString(handle, "\n");
        
        // 基本設定
        FileWriteString(handle, "[Basic Settings]\n");
        FileWriteString(handle, "RiskPercent=" + DoubleToString(m_currentProfile.riskPercent, 2) + "\n");
        FileWriteString(handle, "DefaultLots=" + DoubleToString(m_currentProfile.defaultLots, 2) + "\n");
        FileWriteString(handle, "UseAutoLot=" + (m_currentProfile.useAutoLot ? "true" : "false") + "\n");
        FileWriteString(handle, "\n");
        
        // 戦略設定
        FileWriteString(handle, "[Strategy Settings]\n");
        FileWriteString(handle, "EnablePatternBreak=" + (m_currentProfile.enablePatternBreak ? "true" : "false") + "\n");
        FileWriteString(handle, "EnablePBPullback=" + (m_currentProfile.enablePBPullback ? "true" : "false") + "\n");
        FileWriteString(handle, "EnablePBCombo=" + (m_currentProfile.enablePBCombo ? "true" : "false") + "\n");
        FileWriteString(handle, "\n");
        
        // パターンブレイク設定
        FileWriteString(handle, "[Pattern Break Settings]\n");
        FileWriteString(handle, "MinBuildupBars=" + IntegerToString(m_currentProfile.minBuildupBars) + "\n");
        FileWriteString(handle, "MaxBuildupBars=" + IntegerToString(m_currentProfile.maxBuildupBars) + "\n");
        FileWriteString(handle, "BuildupRangePips=" + DoubleToString(m_currentProfile.buildupRangePips, 1) + "\n");
        FileWriteString(handle, "BreakoutMinPips=" + DoubleToString(m_currentProfile.breakoutMinPips, 1) + "\n");
        FileWriteString(handle, "BreakoutMaxPips=" + DoubleToString(m_currentProfile.breakoutMaxPips, 1) + "\n");
        FileWriteString(handle, "ConfirmationBars=" + IntegerToString(m_currentProfile.confirmationBars) + "\n");
        FileWriteString(handle, "\n");
        
        // エントリー/エグジット設定
        FileWriteString(handle, "[Entry Exit Settings]\n");
        FileWriteString(handle, "StopLossPips=" + DoubleToString(m_currentProfile.stopLossPips, 1) + "\n");
        FileWriteString(handle, "TakeProfitPips=" + DoubleToString(m_currentProfile.takeProfitPips, 1) + "\n");
        FileWriteString(handle, "UseTrailingStop=" + (m_currentProfile.useTrailingStop ? "true" : "false") + "\n");
        FileWriteString(handle, "TrailingStartPips=" + DoubleToString(m_currentProfile.trailingStartPips, 1) + "\n");
        FileWriteString(handle, "TrailingStepPips=" + DoubleToString(m_currentProfile.trailingStepPips, 1) + "\n");
        FileWriteString(handle, "UseBreakEven=" + (m_currentProfile.useBreakEven ? "true" : "false") + "\n");
        FileWriteString(handle, "BreakEvenTrigger=" + DoubleToString(m_currentProfile.breakEvenTrigger, 1) + "\n");
        FileWriteString(handle, "\n");
        
        // フィルター設定
        FileWriteString(handle, "[Filter Settings]\n");
        FileWriteString(handle, "MaxEMADistance=" + DoubleToString(m_currentProfile.maxEMADistance, 1) + "\n");
        FileWriteString(handle, "MaxSpreadPips=" + DoubleToString(m_currentProfile.maxSpreadPips, 1) + "\n");
        FileWriteString(handle, "UseTimeFilter=" + (m_currentProfile.useTimeFilter ? "true" : "false") + "\n");
        FileWriteString(handle, "StartHour=" + IntegerToString(m_currentProfile.startHour) + "\n");
        FileWriteString(handle, "EndHour=" + IntegerToString(m_currentProfile.endHour) + "\n");
        FileWriteString(handle, "\n");
        
        // リスク管理設定
        FileWriteString(handle, "[Risk Management]\n");
        FileWriteString(handle, "MaxTradesPerDay=" + IntegerToString(m_currentProfile.maxTradesPerDay) + "\n");
        FileWriteString(handle, "MaxDailyLoss=" + DoubleToString(m_currentProfile.maxDailyLoss, 1) + "\n");
        FileWriteString(handle, "CooldownMinutes=" + IntegerToString(m_currentProfile.cooldownMinutes) + "\n");
        FileWriteString(handle, "MaxConcurrentTrades=" + IntegerToString(m_currentProfile.maxConcurrentTrades) + "\n");
        
        FileClose(handle);
        
        Print("Profile saved successfully: ", profileName);
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| プロファイル読み込み                                             |
    //+------------------------------------------------------------------+
    bool LoadProfile(string profileName) {
        if(profileName == "") {
            m_lastError = "Profile name cannot be empty";
            return false;
        }
        
        // プリセットプロファイルチェック
        if(profileName == "Safe") {
            m_currentProfile = m_safeProfile;
            return true;
        } else if(profileName == "Balanced") {
            m_currentProfile = m_balancedProfile;
            return true;
        } else if(profileName == "Aggressive") {
            m_currentProfile = m_aggressiveProfile;
            return true;
        } else if(profileName == "Default") {
            m_currentProfile = m_defaultProfile;
            return true;
        }
        
        // ファイルから読み込み
        string filename = m_profilesPath + profileName + ".conf";
        
        if(!FileIsExist(filename)) {
            m_lastError = "Profile file not found: " + filename;
            return false;
        }
        
        int handle = FileOpen(filename, FILE_READ|FILE_TXT);
        if(handle == INVALID_HANDLE) {
            m_lastError = "Failed to open profile file: " + filename;
            return false;
        }
        
        // プロファイル初期化
        ConfigProfile newProfile = m_defaultProfile;
        newProfile.profileName = profileName;
        
        // ファイル読み込み
        string section = "";
        while(!FileIsEnding(handle)) {
            string line = FileReadString(handle);
            
            // コメント行とは空行をスキップ
            if(StringLen(line) == 0 || StringSubstr(line, 0, 1) == "#") continue;
            
            // セクション判定
            if(StringSubstr(line, 0, 1) == "[") {
                section = line;
                continue;
            }
            
            // キー=値の解析
            int pos = StringFind(line, "=");
            if(pos <= 0) continue;
            
            string key = StringSubstr(line, 0, pos);
            string value = StringSubstr(line, pos + 1);
            
            // セクション別の処理
            if(section == "[Basic Settings]") {
                if(key == "RiskPercent") newProfile.riskPercent = StringToDouble(value);
                else if(key == "DefaultLots") newProfile.defaultLots = StringToDouble(value);
                else if(key == "UseAutoLot") newProfile.useAutoLot = (value == "true");
            }
            else if(section == "[Strategy Settings]") {
                if(key == "EnablePatternBreak") newProfile.enablePatternBreak = (value == "true");
                else if(key == "EnablePBPullback") newProfile.enablePBPullback = (value == "true");
                else if(key == "EnablePBCombo") newProfile.enablePBCombo = (value == "true");
            }
            else if(section == "[Pattern Break Settings]") {
                if(key == "MinBuildupBars") newProfile.minBuildupBars = (int)StringToInteger(value);
                else if(key == "MaxBuildupBars") newProfile.maxBuildupBars = (int)StringToInteger(value);
                else if(key == "BuildupRangePips") newProfile.buildupRangePips = StringToDouble(value);
                else if(key == "BreakoutMinPips") newProfile.breakoutMinPips = StringToDouble(value);
                else if(key == "BreakoutMaxPips") newProfile.breakoutMaxPips = StringToDouble(value);
                else if(key == "ConfirmationBars") newProfile.confirmationBars = (int)StringToInteger(value);
            }
            else if(section == "[Entry Exit Settings]") {
                if(key == "StopLossPips") newProfile.stopLossPips = StringToDouble(value);
                else if(key == "TakeProfitPips") newProfile.takeProfitPips = StringToDouble(value);
                else if(key == "UseTrailingStop") newProfile.useTrailingStop = (value == "true");
                else if(key == "TrailingStartPips") newProfile.trailingStartPips = StringToDouble(value);
                else if(key == "TrailingStepPips") newProfile.trailingStepPips = StringToDouble(value);
                else if(key == "UseBreakEven") newProfile.useBreakEven = (value == "true");
                else if(key == "BreakEvenTrigger") newProfile.breakEvenTrigger = StringToDouble(value);
            }
            else if(section == "[Filter Settings]") {
                if(key == "MaxEMADistance") newProfile.maxEMADistance = StringToDouble(value);
                else if(key == "MaxSpreadPips") newProfile.maxSpreadPips = StringToDouble(value);
                else if(key == "UseTimeFilter") newProfile.useTimeFilter = (value == "true");
                else if(key == "StartHour") newProfile.startHour = (int)StringToInteger(value);
                else if(key == "EndHour") newProfile.endHour = (int)StringToInteger(value);
            }
            else if(section == "[Risk Management]") {
                if(key == "MaxTradesPerDay") newProfile.maxTradesPerDay = (int)StringToInteger(value);
                else if(key == "MaxDailyLoss") newProfile.maxDailyLoss = StringToDouble(value);
                else if(key == "CooldownMinutes") newProfile.cooldownMinutes = (int)StringToInteger(value);
                else if(key == "MaxConcurrentTrades") newProfile.maxConcurrentTrades = (int)StringToInteger(value);
            }
        }
        
        FileClose(handle);
        
        m_currentProfile = newProfile;
        Print("Profile loaded successfully: ", profileName);
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| プロファイルリスト取得                                           |
    //+------------------------------------------------------------------+
    void GetProfileList(string &profiles[]) {
        // プリセットプロファイル
        ArrayResize(profiles, 4);
        profiles[0] = "Default";
        profiles[1] = "Safe";
        profiles[2] = "Balanced";
        profiles[3] = "Aggressive";
        
        // カスタムプロファイル検索
        string searchPattern = m_profilesPath + "*.conf";
        string filename;
        int searchHandle = FileFindFirst(searchPattern, filename);
        
        if(searchHandle != INVALID_HANDLE) {
            do {
                // .conf拡張子を除去
                string profileName = StringSubstr(filename, 0, StringLen(filename) - 5);
                
                // 配列に追加
                int size = ArraySize(profiles);
                ArrayResize(profiles, size + 1);
                profiles[size] = profileName;
                
            } while(FileFindNext(searchHandle, filename));
            
            FileFindClose(searchHandle);
        }
    }
    
    //+------------------------------------------------------------------+
    //| 現在のプロファイル取得                                           |
    //+------------------------------------------------------------------+
    ConfigProfile GetCurrentProfile() {
        return m_currentProfile;
    }
    
    //+------------------------------------------------------------------+
    //| 現在のプロファイル設定                                           |
    //+------------------------------------------------------------------+
    void SetCurrentProfile(const ConfigProfile &profile) {
        m_currentProfile = profile;
    }
    
    //+------------------------------------------------------------------+
    //| プロファイル削除                                                 |
    //+------------------------------------------------------------------+
    bool DeleteProfile(string profileName) {
        // プリセットは削除不可
        if(profileName == "Default" || profileName == "Safe" || 
           profileName == "Balanced" || profileName == "Aggressive") {
            m_lastError = "Cannot delete preset profiles";
            return false;
        }
        
        string filename = m_profilesPath + profileName + ".conf";
        
        if(!FileIsExist(filename)) {
            m_lastError = "Profile not found: " + profileName;
            return false;
        }
        
        if(FileDelete(filename)) {
            Print("Profile deleted: ", profileName);
            return true;
        }
        
        m_lastError = "Failed to delete profile: " + profileName;
        return false;
    }
    
    //+------------------------------------------------------------------+
    //| エラー取得                                                       |
    //+------------------------------------------------------------------+
    string GetLastError() {
        return m_lastError;
    }
    
    //+------------------------------------------------------------------+
    //| プロファイルエクスポート（JSON形式）                             |
    //+------------------------------------------------------------------+
    bool ExportProfileAsJSON(string profileName, string exportPath = "") {
        if(exportPath == "") {
            exportPath = m_configPath + profileName + ".json";
        }
        
        int handle = FileOpen(exportPath, FILE_WRITE|FILE_TXT);
        if(handle == INVALID_HANDLE) {
            m_lastError = "Failed to create export file";
            return false;
        }
        
        // JSON形式で書き込み
        FileWriteString(handle, "{\n");
        FileWriteString(handle, "  \"profileName\": \"" + m_currentProfile.profileName + "\",\n");
        FileWriteString(handle, "  \"description\": \"" + m_currentProfile.description + "\",\n");
        FileWriteString(handle, "  \"settings\": {\n");
        
        // 基本設定
        FileWriteString(handle, "    \"basic\": {\n");
        FileWriteString(handle, "      \"riskPercent\": " + DoubleToString(m_currentProfile.riskPercent, 2) + ",\n");
        FileWriteString(handle, "      \"defaultLots\": " + DoubleToString(m_currentProfile.defaultLots, 2) + ",\n");
        FileWriteString(handle, "      \"useAutoLot\": " + (m_currentProfile.useAutoLot ? "true" : "false") + "\n");
        FileWriteString(handle, "    },\n");
        
        // 戦略設定
        FileWriteString(handle, "    \"strategy\": {\n");
        FileWriteString(handle, "      \"enablePatternBreak\": " + (m_currentProfile.enablePatternBreak ? "true" : "false") + ",\n");
        FileWriteString(handle, "      \"enablePBPullback\": " + (m_currentProfile.enablePBPullback ? "true" : "false") + ",\n");
        FileWriteString(handle, "      \"enablePBCombo\": " + (m_currentProfile.enablePBCombo ? "true" : "false") + "\n");
        FileWriteString(handle, "    },\n");
        
        // リスク管理
        FileWriteString(handle, "    \"risk\": {\n");
        FileWriteString(handle, "      \"stopLossPips\": " + DoubleToString(m_currentProfile.stopLossPips, 1) + ",\n");
        FileWriteString(handle, "      \"takeProfitPips\": " + DoubleToString(m_currentProfile.takeProfitPips, 1) + ",\n");
        FileWriteString(handle, "      \"maxTradesPerDay\": " + IntegerToString(m_currentProfile.maxTradesPerDay) + ",\n");
        FileWriteString(handle, "      \"maxDailyLoss\": " + DoubleToString(m_currentProfile.maxDailyLoss, 1) + "\n");
        FileWriteString(handle, "    }\n");
        
        FileWriteString(handle, "  }\n");
        FileWriteString(handle, "}\n");
        
        FileClose(handle);
        
        Print("Profile exported as JSON: ", exportPath);
        return true;
    }
    
private:
    //+------------------------------------------------------------------+
    //| デフォルトプロファイル初期化                                     |
    //+------------------------------------------------------------------+
    void InitializeDefaultProfile() {
        m_defaultProfile.profileName = "Default";
        m_defaultProfile.description = "Default configuration profile";
        m_defaultProfile.createdDate = TimeCurrent();
        m_defaultProfile.modifiedDate = TimeCurrent();
        
        // 基本設定
        m_defaultProfile.riskPercent = 2.0;
        m_defaultProfile.defaultLots = 0.01;
        m_defaultProfile.useAutoLot = false;
        
        // 戦略設定
        m_defaultProfile.enablePatternBreak = true;
        m_defaultProfile.enablePBPullback = false;
        m_defaultProfile.enablePBCombo = false;
        
        // パターンブレイク設定
        m_defaultProfile.minBuildupBars = 3;
        m_defaultProfile.maxBuildupBars = 10;
        m_defaultProfile.buildupRangePips = 10.0;
        m_defaultProfile.breakoutMinPips = 2.0;
        m_defaultProfile.breakoutMaxPips = 5.0;
        m_defaultProfile.confirmationBars = 2;
        
        // エントリー/エグジット
        m_defaultProfile.stopLossPips = 10.0;
        m_defaultProfile.takeProfitPips = 20.0;
        m_defaultProfile.useTrailingStop = false;
        m_defaultProfile.trailingStartPips = 10.0;
        m_defaultProfile.trailingStepPips = 5.0;
        m_defaultProfile.useBreakEven = true;
        m_defaultProfile.breakEvenTrigger = 5.0;
        
        // フィルター
        m_defaultProfile.maxEMADistance = 15.0;
        m_defaultProfile.maxSpreadPips = 2.0;
        m_defaultProfile.useTimeFilter = true;
        m_defaultProfile.startHour = 7;
        m_defaultProfile.endHour = 21;
        
        // リスク管理
        m_defaultProfile.maxTradesPerDay = 5;
        m_defaultProfile.maxDailyLoss = 5.0;
        m_defaultProfile.cooldownMinutes = 30;
        m_defaultProfile.maxConcurrentTrades = 1;
    }
    
    //+------------------------------------------------------------------+
    //| プリセットプロファイル初期化                                     |
    //+------------------------------------------------------------------+
    void InitializePresetProfiles() {
        // 安全設定
        m_safeProfile = m_defaultProfile;
        m_safeProfile.profileName = "Safe";
        m_safeProfile.description = "Conservative settings for beginners";
        m_safeProfile.riskPercent = 1.0;
        m_safeProfile.defaultLots = 0.01;
        m_safeProfile.useAutoLot = false;
        m_safeProfile.enablePBPullback = false;
        m_safeProfile.enablePBCombo = false;
        m_safeProfile.stopLossPips = 12.0;
        m_safeProfile.maxTradesPerDay = 3;
        m_safeProfile.maxDailyLoss = 3.0;
        
        // バランス設定
        m_balancedProfile = m_defaultProfile;
        m_balancedProfile.profileName = "Balanced";
        m_balancedProfile.description = "Balanced risk and reward";
        m_balancedProfile.riskPercent = 1.5;
        m_balancedProfile.useAutoLot = true;
        m_balancedProfile.enablePBPullback = true;
        m_balancedProfile.useTrailingStop = true;
        
        // アグレッシブ設定
        m_aggressiveProfile = m_defaultProfile;
        m_aggressiveProfile.profileName = "Aggressive";
        m_aggressiveProfile.description = "Maximum profit potential";
        m_aggressiveProfile.riskPercent = 2.0;
        m_aggressiveProfile.useAutoLot = true;
        m_aggressiveProfile.enablePatternBreak = true;
        m_aggressiveProfile.enablePBPullback = true;
        m_aggressiveProfile.enablePBCombo = true;
        m_aggressiveProfile.minBuildupBars = 2;
        m_aggressiveProfile.breakoutMinPips = 1.5;
        m_aggressiveProfile.maxTradesPerDay = 10;
        m_aggressiveProfile.useTrailingStop = true;
        m_aggressiveProfile.useBreakEven = true;
    }
};

//+------------------------------------------------------------------+