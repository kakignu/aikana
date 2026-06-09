# AIかな — ローカルLLM日本語IME

ローマ字（および日英混在テキスト）を、ローカルLLM（LM Studio / Ollama）で日本語に変換する macOS 用の入力メソッド（IME）。
段落をまるごとローマ字で書いてから `Enter` で一気に変換するので、変換確定で思考が途切れません。

> 元ネタ: AIを使ったローマ字日本語変換を自作IMEとして実装するアイデア。

## 特徴

- **段落単位変換** — ローマ字を溜めて（下線プレビュー）、`Enter` で段落ごとAI変換 → 確定
- **日英混在OK** — モード切替なしで適切に変換
- **100%自分のコントロール下** — AIが文章を創作するのではなく「表記変換」に徹する
- **カスタマイズ可能** — 文体・固有名詞を `config.json` のプロンプトに登録して精度向上
- **完全ローカル** — ローカルLLMでオフライン動作。テキストは外部に送られない

## 必要環境

- macOS 13+（開発・確認は macOS 26 / Xcode 26 / Swift 6.3）
- OpenAI互換のローカルLLMサーバ（どちらでも可）:
  - **LM Studio**（既定）— `http://localhost:1234/v1/chat/completions`、モデル例 `google/gemma-4-e4b`
  - **Ollama** — `http://localhost:11434/v1/chat/completions`、モデル例 `qwen2.5:7b`

LM Studio ならアプリでモデルをロードして "Start Server"（port 1234）するだけ。
Ollama を使う場合は `config.json` の `endpoint` と `model` を上記に変更してください。

## インストール

### A. インストーラ（.pkg）でインストール ← かんたん

[Releases](../../releases/latest) から `AIKana-x.y.pkg` をダウンロードしてダブルクリック。
`/Library/Input Methods` に導入されます（管理者パスワードが必要）。

> ⚠️ ad-hoc署名のため、初回は「開発元を確認できない」と出ることがあります。
> その場合は `.pkg` を**右クリック →「開く」**、もしくは
> システム設定 → プライバシーとセキュリティ →「このまま開く」で許可してください。

### B. ソースからビルド（開発者向け）

```bash
./build.sh      # build/AIKana.app を生成（swiftc + ad-hoc 署名）
./install.sh    # ~/Library/Input Methods にコピーして登録用に起動
# もしくは
./make-pkg.sh   # dist/AIKana-0.2.pkg を生成（/Library/Input Methods へシステム導入）
```

### 有効化（A/B共通）

1. システム設定 → キーボード → 入力ソース → 編集… → 「+」
2. 「日本語」から **AIかな** を追加
3. 入力メニュー（または `Ctrl+Space`）で AIかな に切替

> 一覧に出ない場合は一度ログアウト→ログイン。

## 使い方

| キー | 動作 |
|------|------|
| 英字・記号・スペース | バッファに溜める（下線プレビュー） |
| `Enter` | バッファ（段落）をAI変換して確定 |
| `Shift+Enter` | バッファ内で改行（複数行の段落を作る） |
| `Backspace` | バッファを1文字削除 |
| `Esc` | バッファを破棄 |
| バッファが空のとき `Enter` | 通常の改行として通過 |

変換中は `⟳` が表示され、完了すると日本語に置き換わります。
変換に失敗した場合はローマ字のまま確定されます（入力を失わない）。

## 設定 / バックエンド切替

LM Studio と Ollama の両方を登録しておき、`backend` でどちらを使うか切り替えます。

**メニューバーの AIかな メニュー**から「バックエンド: LM Studio / Ollama」をクリックするだけで切替可能（現在の選択にチェックが付きます）。同メニューから「設定ファイルを編集…」「LLM 接続テスト」も可能。

設定ファイル `~/.config/aikana/config.json`（初回起動時に自動生成）:

```json
{
  "backend": "lmstudio",
  "lmstudio_endpoint": "http://localhost:1234/v1/chat/completions",
  "lmstudio_model": "google/gemma-4-e4b",
  "ollama_endpoint": "http://localhost:11434/v1/chat/completions",
  "ollama_model": "qwen2.5:7b",
  "temperature": 0.3,
  "systemPrompt": "..."
}
```

- **backend** — `"lmstudio"` か `"ollama"`。アクティブな endpoint/model がこれで決まる
- **lmstudio_* / ollama_*** — 各バックエンドのURLとモデル名
- **systemPrompt** — 文体（常体/敬体）、よく使う固有名詞などを書くと変換精度が上がる

編集は次の変換からすぐ反映されます（再起動不要）。

### バックエンドの起動
- **LM Studio** — アプリでモデルをロード → "Start Server"（port 1234）
- **Ollama** — `brew install ollama && brew services start ollama && ollama pull qwen2.5:7b`

## 仕組み

```
Sources/
  main.swift                 IMKServer の起動
  RomajiInputController.swift IMKInputController サブクラス。バッファ管理・キー処理・変換
  LLMClient.swift             OpenAI互換 /v1/chat/completions へのHTTPクライアント
  Config.swift                ~/.config/aikana/config.json の読み書き
Resources/Info.plist          入力メソッドとしての宣言（ComponentInputModeDict 等）
```

## アンインストール

```bash
killall AIKana 2>/dev/null
rm -rf "$HOME/Library/Input Methods/AIKana.app"
# システム設定の入力ソースからも削除
```

## トラブルシュート

- **入力ソース一覧に出ない** — `./install.sh` を再実行し、ログアウト/ログインを試す。`/tmp/aikana.log` も確認
- **変換が無反応 / 失敗** — LLMサーバが起動中か（LM Studio の "Start Server" / `ollama serve`）、モデルがロード済みか確認。メニューの「LLM 接続テスト」も使える
- **変換が遅い** — より小さいモデル（`qwen2.5:3b`）に変更
