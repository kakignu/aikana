import Foundation

/// User-editable configuration, loaded fresh on every conversion so edits to
/// ~/.config/aikana/config.json take effect without restarting the IME.
///
/// Two backends are pre-configured (LM Studio and Ollama); `backend` selects
/// which one is active. The active endpoint/model are exposed as computed
/// `endpoint` / `model` so the rest of the app doesn't care which is selected.
struct Config {
    enum Backend: String { case lmstudio, ollama }

    var backend: Backend
    var lmstudioEndpoint: String
    var lmstudioModel: String
    var ollamaEndpoint: String
    var ollamaModel: String
    var temperature: Double
    var systemPrompt: String

    /// Active endpoint for the selected backend.
    var endpoint: String { backend == .ollama ? ollamaEndpoint : lmstudioEndpoint }
    /// Active model for the selected backend.
    var model: String { backend == .ollama ? ollamaModel : lmstudioModel }

    static let dir = (NSHomeDirectory() as NSString)
        .appendingPathComponent(".config/aikana")
    static let path = (dir as NSString)
        .appendingPathComponent("config.json")

    static let defaultSystemPrompt = """
    あなたは日本語入力(IME)の変換エンジンです。
    ユーザーが打ち込んだローマ字、または日本語と英語が混在したテキストを受け取り、
    自然で読みやすい日本語の文章に変換します。

    ルール:
    - 出力は変換後の本文だけ。説明・前置き・引用符・コードブロックは一切付けない。
    - ローマ字は文脈に合った漢字かな交じり文に変換する(例: "kyou no kaigi" → "今日の会議")。
    - すでに日本語の部分や、固有名詞・英単語・記号はそのまま活かす。
    - 文の意味や語順を勝手に創作・脚色しない。あくまで表記変換に徹する。
    - 改行は入力の改行を尊重する。

    # 文体・固有名詞などのカスタマイズ(必要に応じて編集)
    - 文体: 常体/敬体は入力に合わせる。
    - よく使う固有名詞: (ここに登録すると変換精度が上がります)
    """

    static let defaultConfig = Config(
        backend: .lmstudio,
        lmstudioEndpoint: "http://localhost:1234/v1/chat/completions",
        lmstudioModel: "google/gemma-4-e4b",
        ollamaEndpoint: "http://localhost:11434/v1/chat/completions",
        ollamaModel: "qwen2.5:7b",
        temperature: 0.3,
        systemPrompt: defaultSystemPrompt
    )

    /// Load config from disk, creating a default file on first run. Never throws —
    /// falls back to defaults so the IME keeps working even if the file is broken.
    static func load() -> Config {
        let fm = FileManager.default
        if !fm.fileExists(atPath: path) {
            writeDefault()
            return defaultConfig
        }
        guard let data = fm.contents(atPath: path),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            NSLog("AIKana: config unreadable, using defaults")
            return defaultConfig
        }
        let d = defaultConfig
        // Back-compat: an old flat config used top-level "endpoint"/"model".
        // Treat those as the LM Studio slot if the new keys are absent.
        let legacyEndpoint = obj["endpoint"] as? String
        let legacyModel = obj["model"] as? String
        return Config(
            backend: Backend(rawValue: (obj["backend"] as? String ?? "")) ?? d.backend,
            lmstudioEndpoint: obj["lmstudio_endpoint"] as? String ?? legacyEndpoint ?? d.lmstudioEndpoint,
            lmstudioModel: obj["lmstudio_model"] as? String ?? legacyModel ?? d.lmstudioModel,
            ollamaEndpoint: obj["ollama_endpoint"] as? String ?? d.ollamaEndpoint,
            ollamaModel: obj["ollama_model"] as? String ?? d.ollamaModel,
            temperature: obj["temperature"] as? Double ?? d.temperature,
            systemPrompt: obj["systemPrompt"] as? String ?? d.systemPrompt
        )
    }

    static func writeDefaultIfMissing() {
        if !FileManager.default.fileExists(atPath: path) { writeDefault() }
    }

    static func writeDefault() {
        write(defaultConfig)
    }

    /// Persist a config to disk (pretty-printed JSON).
    static func write(_ c: Config) {
        let fm = FileManager.default
        try? fm.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let obj: [String: Any] = [
            "backend": c.backend.rawValue,
            "lmstudio_endpoint": c.lmstudioEndpoint,
            "lmstudio_model": c.lmstudioModel,
            "ollama_endpoint": c.ollamaEndpoint,
            "ollama_model": c.ollamaModel,
            "temperature": c.temperature,
            "systemPrompt": c.systemPrompt,
        ]
        if let data = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .withoutEscapingSlashes, .sortedKeys]) {
            try? data.write(to: URL(fileURLWithPath: path))
            NSLog("AIKana: wrote config to \(path)")
        }
    }

    /// Switch the active backend and persist the change.
    static func setBackend(_ backend: Backend) {
        var c = load()
        c.backend = backend
        write(c)
    }
}
