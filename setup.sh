#!/bin/bash

# MT4 Trading Tools セットアップスクリプト

echo "==================================="
echo " MT4 Trading Tools セットアップ"
echo "==================================="

# Git設定の確認
if [ -z "$(git config user.name)" ] || [ -z "$(git config user.email)" ]; then
    echo "Git設定が必要です。"
    read -p "名前を入力してください: " name
    read -p "メールアドレスを入力してください: " email
    git config user.name "$name"
    git config user.email "$email"
fi

# エンコーディング変換用の関数を.bashrcに追加
echo ""
echo "MQL4ファイル読み取り用の関数を設定しています..."
cat >> ~/.bashrc << 'EOF'

# MQL4ファイルをUTF-8で表示する関数
mql4cat() {
    if [ -f "$1" ]; then
        iconv -f UTF-16LE -t UTF-8 "$1" 2>/dev/null || cat "$1"
    else
        echo "ファイルが見つかりません: $1"
    fi
}
EOF

echo ""
echo "セットアップ完了！"
echo ""
echo "=== Claude Codeでの開発開始方法 ==="
echo "1. 新しいターミナルを開く（.bashrc反映のため）"
echo "2. プロジェクトディレクトリに移動："
echo "   cd $(pwd)"
echo "3. Claude Codeを起動："
echo "   claude"
echo ""
echo "Claude Codeが.clinerrulesを自動的に読み込み、"
echo "プロジェクトのコンテキストが適用されます。"
echo ""
echo "=== 便利なコマンド ==="
echo "MQL4ファイルを読む: mql4cat ファイル名"
echo "例: mql4cat CT_Trail_2.00/CT_Trail_2.00.mq4"
echo ""