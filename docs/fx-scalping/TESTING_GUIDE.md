# FX 5分足スキャルピングEA - テストガイド

## 📋 インストール手順

### 1. ファイルの配置

MT4のデータフォルダを開いて、以下のようにファイルを配置してください：

```
MT4データフォルダ/
├── MQL4/
│   ├── Experts/
│   │   └── FX5MinScalpingEA.mq4              # メインEA
│   └── Include/
│       ├── PluginBase.mqh                    # 既存（変更不要）
│       ├── Core/
│       │   ├── OrderManager.mqh              # 既存（変更不要）
│       │   └── AccountManager.mqh            # 既存（変更不要）
│       └── FX5MinScalping/                   # 新規フォルダ
│           ├── DataStructures.mqh
│           ├── MarketAnalyzer.mqh
│           ├── BuildupDetector.mqh
│           └── PatternBreakPlugin.mqh
```

### 2. コンパイル手順

1. **MT4を起動**
2. **MetaEditor を開く**（F4キー）
3. **Navigator から `FX5MinScalpingEA.mq4` を開く**
4. **コンパイル**（F7キー）
5. **エラーがないことを確認**

### 3. エラーが出た場合

#### よくあるコンパイルエラーと対処法：

**エラー: "Cannot open include file"**
- 原因：インクルードファイルのパスが間違っている
- 対処：FX5MinScalpingフォルダが正しい場所にあるか確認

**エラー: "COrderManager - undeclared identifier"**
- 原因：既存のCore/OrderManager.mqhが見つからない
- 対処：既存のmt4-trading-toolsのCoreフォルダを確認

## 🚀 EA実行手順

### 1. チャート設定

1. **EUR/USD の5分足チャートを開く**
2. **チャート上で右クリック** → **エキスパートアドバイザ** → **FX5MinScalpingEA**
3. **設定画面で以下を確認**：
   - 「自動売買を許可」にチェック
   - 「DLLの使用を許可」にチェック（不要だが念のため）

### 2. 推奨初期設定

#### デモ口座でのテスト用設定：
```
=== Basic Settings ===
MagicNumber: 20250825        # そのまま
RiskPercent: 2.0             # 2%リスク
DefaultLots: 0.01            # 最小ロット
UseAutoLot: false            # 最初は固定ロットでテスト

=== Pattern Break Settings ===
EnablePatternBreak: true     # 有効
MinBuildupBars: 3            # 最小3本
MaxBuildupBars: 10           # 最大10本
BuildupRangePips: 10.0       # 10pips以内
BreakoutMinPips: 2.0         # 最小2pips
BreakoutMaxPips: 5.0         # 最大5pips
ConfirmationBars: 2          # 2本確認

=== Entry/Exit Settings ===
StopLossPips: 10.0           # 10pips損切り
TakeProfitPips: 20.0         # 20pips利確
UseTrailingStop: true        # トレール有効
TrailingStartPips: 10.0      # 10pipsで開始
TrailingStepPips: 5.0        # 5pips幅
UseBreakEven: true           # BE有効
BreakEvenTrigger: 5.0        # 5pipsでBE

=== Filter Settings ===
MaxEMADistance: 15.0         # 25EMAから15pips以内
MaxSpreadPips: 2.0           # スプレッド2pips以下
UseTimeFilter: true          # 時間フィルター有効
StartHour: 7                 # ロンドン開始
EndHour: 21                  # NY終了

=== Risk Management ===
MaxTradesPerDay: 5           # 1日5トレードまで
MaxDailyLoss: 5.0            # 日次5%損失で停止
CooldownMinutes: 30          # 30分クールダウン
MaxConcurrentTrades: 1       # 同時1ポジションのみ
```

### 3. 動作確認

#### EA起動後の確認項目：

1. **エキスパートタブを確認**
   - "FX 5-Minute Scalping EA Initialized Successfully" のメッセージ
   - エラーメッセージがないこと

2. **チャート上の表示**
   - 左上に情報パネルが表示される
   - Status: Active と表示される

3. **初期動作テスト**
   - チャートを観察して、パターンとビルドアップの検出を待つ
   - 黄色いボックスが表示されれば、ビルドアップ検出成功

## 🔍 バックテスト手順

### 1. Strategy Testerの設定

1. **Strategy Tester を開く**（Ctrl+R）
2. **設定項目**：
   - EA: FX5MinScalpingEA
   - 通貨ペア: EURUSD
   - 期間: M5（5分足）
   - モデル: 全ティック（最も正確）
   - スプレッド: 現在値（または2）
   - 期間: 直近3ヶ月から開始

### 2. 最適化設定

最適化する場合の推奨パラメータ範囲：

| パラメータ | 開始 | ステップ | 終了 |
|-----------|------|----------|------|
| MinBuildupBars | 3 | 1 | 5 |
| MaxBuildupBars | 8 | 1 | 12 |
| BuildupRangePips | 8.0 | 1.0 | 12.0 |
| BreakoutMinPips | 1.5 | 0.5 | 3.0 |
| StopLossPips | 8.0 | 1.0 | 12.0 |
| TakeProfitPips | 16.0 | 2.0 | 24.0 |

## 📊 パフォーマンス評価

### 成功基準

| 指標 | 最低基準 | 目標値 |
|------|----------|--------|
| 勝率 | 45% | 55% |
| プロフィットファクター | 1.3 | 1.8 |
| 最大ドローダウン | 15% | 10%以下 |
| 月間トレード数 | 20回 | 40回 |
| リスクリワード比 | 1:1.5 | 1:2 |

### トレード記録の確認

1. **ターミナルの「口座履歴」タブ**
2. **右クリック** → **レポートの保存**
3. **HTML形式で保存して分析**

## 🐛 デバッグ方法

### ログの確認

1. **エキスパートタブ**でリアルタイムログを確認
2. **ジャーナルタブ**でシステムメッセージを確認

### よくある問題と解決策

#### 問題: トレードが実行されない
- **確認1**: 自動売買ボタンがONになっているか
- **確認2**: パターンが検出されているか（黄色いボックス）
- **確認3**: 時間フィルターで除外されていないか
- **確認4**: スプレッドが条件を満たしているか

#### 問題: エラー4109（Trade not allowed）
- **解決**: EAの設定で「自動売買を許可」にチェック

#### 問題: エラー130（Invalid stops）
- **解決**: ブローカーの最小ストップレベルを確認
  ```mql4
  double minStop = MarketInfo(Symbol(), MODE_STOPLEVEL);
  Print("Minimum stop level: ", minStop);
  ```

## 📈 リアルトレード移行チェックリスト

### デモ口座での確認事項

- [ ] 最低1ヶ月のフォワードテスト完了
- [ ] 勝率45%以上達成
- [ ] 最大DD 10%以内
- [ ] 月間20トレード以上実行
- [ ] すべての機能が正常動作

### リアル口座での初期設定

1. **最小ロットから開始**（0.01ロット）
2. **リスク設定を保守的に**（1%以下）
3. **最初の1週間は監視を強化**
4. **問題があれば即座に停止**

## 💡 トレードのヒント

### 最適な取引時間
- **ロンドンオープン**（日本時間16:00-17:00）
- **NYオープン**（日本時間21:00-22:00）
- **ロンドン-NYオーバーラップ**（日本時間21:00-01:00）

### 避けるべき時間
- **アジア時間の深夜**（ボラティリティ低）
- **重要指標発表前後30分**
- **金曜日のNY午後**（週末リスク）
- **月曜日の早朝**（ギャップリスク）

## 📞 サポート

問題が発生した場合：

1. **エラーメッセージをコピー**
2. **ログファイルを保存**
3. **設定のスクリーンショットを取得**
4. **GitHubのIssueで報告**

---
*最終更新: 2025-08-25*