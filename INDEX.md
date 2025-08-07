# MT4 Trading Tools ドキュメントインデックス

## 📚 ドキュメント一覧

### 概要・紹介
- **[README.md](../README.md)** - プロジェクト概要とクイックスタート
- **[PROJECT_STRUCTURE.md](../PROJECT_STRUCTURE.md)** - プロジェクト構造の視覚的な説明

### 開発者向け
- **[ARCHITECTURE.md](../ARCHITECTURE.md)** - システム設計書（詳細）
- **[DEVELOPMENT.md](../DEVELOPMENT.md)** - 開発ガイドライン
- **[CLAUDE.md](../CLAUDE.md)** - 開発履歴とコンテキスト

### 自動設定
- **[.clinerules](../.clinerules)** - Claude Code自動コンテキスト設定

## 🗺️ ドキュメントマップ

```
初めての方
    ↓
README.md → PROJECT_STRUCTURE.md
    ↓
使用者 → UnifiedTradingEA.mq4を使用
    ↓
開発者 → ARCHITECTURE.md → DEVELOPMENT.md
    ↓
プラグイン開発 → DEVELOPMENT.md#プラグイン開発
```

## 📖 読む順序

### 新規ユーザー向け
1. README.md - 基本的な使い方
2. PROJECT_STRUCTURE.md - 全体像の把握

### 開発者向け
1. CLAUDE.md - プロジェクトの背景理解
2. ARCHITECTURE.md - システム設計の理解
3. DEVELOPMENT.md - 実装方法の学習
4. PROJECT_STRUCTURE.md - ファイル構造の確認

### プラグイン開発者向け
1. ARCHITECTURE.md#4-プラグインシステム
2. DEVELOPMENT.md#プラグイン開発
3. 既存プラグインのソースコード参照

## 🔍 トピック別ガイド

### プラグインアーキテクチャ
- 概要: [CLAUDE.md#プラグインアーキテクチャ](../CLAUDE.md#プラグインアーキテクチャ2025年1月実装)
- 詳細設計: [ARCHITECTURE.md#4-プラグインシステム](../ARCHITECTURE.md#4-プラグインシステム)
- 実装方法: [DEVELOPMENT.md#プラグイン開発](../DEVELOPMENT.md#プラグイン開発)

### リスク管理
- 設計思想: [CLAUDE.md#設計思想](../CLAUDE.md#設計思想)
- 実装: RiskManagerPlugin.mqh
- 設定: 最大損失2%/トレード、5%/日

### GUI開発
- 設計: [ARCHITECTURE.md#6-gui-アーキテクチャ](../ARCHITECTURE.md#6-gui-アーキテクチャ)
- 実装例: UnifiedTradingEA.mq4のCreateMainPanel()

## 📞 サポート

- GitHub Issues: バグ報告・機能要望
- CLAUDE.md: 開発履歴の確認
- .clinerules: Claude Codeでの自動サポート