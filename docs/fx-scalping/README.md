# FX 5分足スキャルピング プロジェクトドキュメント

## 📚 概要
ボブ・ボルマン著「FX 5分足スキャルピング」の手法をMT4 EA（Expert Advisor）として実装するプロジェクトの設計書類です。

## 📁 ドキュメント構成

### 1. [BOOK_SUMMARY.md](BOOK_SUMMARY.md)
書籍から抽出した手法の要約と主要な概念の整理。

### 2. [SETUP_DOCUMENTATION.md](SETUP_DOCUMENTATION.md)
3つの主要セットアップ（パターンブレイク、プルバック、コンビ）の詳細説明。
- エントリー/エグジット条件
- テクニカル要素の定義
- トレード回避条件

### 3. [EA_ARCHITECTURE_DESIGN.md](EA_ARCHITECTURE_DESIGN.md)
EA全体のシステムアーキテクチャ設計。
- モジュール構成
- コアコンポーネントの詳細
- イベント処理フロー

### 4. [PLUGIN_DETAILED_DESIGN.md](PLUGIN_DETAILED_DESIGN.md)
各プラグインの詳細設計とアルゴリズム。
- パターンブレイクプラグイン
- プルバックプラグイン
- コンビプラグイン
- 補助プラグイン

### 5. [DATA_INTERFACE_SPECIFICATION.md](DATA_INTERFACE_SPECIFICATION.md)
データ構造とインターフェースの完全な仕様。
- 基本データ型定義
- インターフェース定義
- 通信プロトコル

### 6. [BACKTEST_PLAN.md](BACKTEST_PLAN.md)
バックテスト実施計画。
- テストシナリオ
- パラメータ最適化戦略
- 評価指標

### 7. [TESTING_GUIDE.md](TESTING_GUIDE.md)
MT4でのテスト実行ガイド。
- インストール手順
- 初期設定の推奨値
- デバッグ方法

## 📦 実装済みモジュール

### コアモジュール
- **DataStructures.mqh** - 共通データ構造定義
- **MarketAnalyzer.mqh** - 市場分析エンジン
- **BuildupDetector.mqh** - ビルドアップパターン検出

### トレード戦略プラグイン
- **PatternBreakPlugin.mqh** - パターンブレイク戦略（実装済み）
- **PBPullbackPlugin.mqh** - パターンブレイク・プルバック戦略（実装済み）
- **PBComboPlugin.mqh** - パターンブレイク・コンビ戦略（実装済み）

### フィルターモジュール
- **TimeFilter.mqh** - 時間帯フィルター（セッション管理）
- **SpreadFilter.mqh** - スプレッドフィルター（適応型閾値）

### メインEA
- **FX5MinScalpingEA.mq4** - 統合EA本体（GUI付き）

## 🚀 クイックスタート

開発を始める際は、以下の順序でドキュメントを確認してください：

1. **BOOK_SUMMARY.md** - 手法の概要を理解
2. **SETUP_DOCUMENTATION.md** - トレードルールを把握
3. **EA_ARCHITECTURE_DESIGN.md** - システム構造を確認
4. **PLUGIN_DETAILED_DESIGN.md** - 実装詳細を理解

## 🎯 プロジェクトの目標

- **月間収益率**: +5%以上
- **最大ドローダウン**: 10%以内
- **勝率**: 50%以上（リスクリワード比1:2）

## 🔗 関連リンク

- [プロジェクトルート](../../README.md)
- [既存コードベース](../../Include/)
- [EA本体](../../Experts/)

---
*最終更新: 2025-08-25*
*実装完了: Pattern Break, PB Pullback, PB Combo, TimeFilter, SpreadFilter*