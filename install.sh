#!/bin/bash
# Install AIKana.app into ~/Library/Input Methods and (re)launch it so the
# system registers the input source. After this, enable it in
# System Settings → Keyboard → Input Sources → + → 日本語 → AIかな.
set -euo pipefail

cd "$(dirname "$0")"

SRC="build/AIKana.app"
DEST_DIR="$HOME/Library/Input Methods"
DEST="$DEST_DIR/AIKana.app"

if [ ! -d "$SRC" ]; then
    echo "!! $SRC not found. Run ./build.sh first." >&2
    exit 1
fi

echo ">>> stopping any running instance"
killall AIKana 2>/dev/null || true

echo ">>> installing to $DEST"
mkdir -p "$DEST_DIR"
rm -rf "$DEST"
cp -R "$SRC" "$DEST"

echo ">>> launching to register input source"
"$DEST/Contents/MacOS/AIKana" >/tmp/aikana.log 2>&1 &
sleep 1

cat <<'EOF'

>>> Installed.

次の手順で有効化してください:
  1. システム設定 → キーボード → 入力ソース → 編集… → 「+」
  2. 「日本語」カテゴリから "AIかな" を選んで追加
  3. メニューバーの入力メニュー(または Ctrl+Space)で AIかな に切替
  4. ローマ字で1段落書いて Enter → AIが日本語に変換して確定

設定(モデル/文体/固有名詞)は ~/.config/romaji-ai/config.json を編集。
ログ: /tmp/aikana.log
EOF
