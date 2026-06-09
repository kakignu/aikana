import Foundation

/// Talks to a local OpenAI-compatible chat server (LM Studio on :1234, or
/// Ollama's /v1 endpoint) to convert romaji / mixed text into Japanese.
final class LLMClient {
    static let shared = LLMClient()

    enum ClientError: LocalizedError {
        case badURL
        case server(String)
        case emptyResponse

        var errorDescription: String? {
            switch self {
            case .badURL: return "endpoint URL が不正です"
            case .server(let s): return "LLM: \(s)"
            case .emptyResponse: return "空の応答"
            }
        }
    }

    /// Convert the given input text, calling completion on a background thread.
    func convert(_ input: String, completion: @escaping (Result<String, Error>) -> Void) {
        let cfg = Config.load()
        guard let url = URL(string: cfg.endpoint) else {
            completion(.failure(ClientError.badURL)); return
        }

        // OpenAI chat-completions request shape.
        let body: [String: Any] = [
            "model": cfg.model,
            "messages": [
                ["role": "system", "content": cfg.systemPrompt],
                ["role": "user", "content": input],
            ],
            "stream": false,
            "temperature": cfg.temperature,
        ]

        var req = URLRequest(url: url, timeoutInterval: 60)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let task = URLSession.shared.dataTask(with: req) { data, response, error in
            if let error = error {
                completion(.failure(error)); return
            }
            guard let data = data else {
                completion(.failure(ClientError.emptyResponse)); return
            }
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                let msg = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
                completion(.failure(ClientError.server(msg))); return
            }
            guard let content = Self.extractContent(data) else {
                completion(.failure(ClientError.emptyResponse)); return
            }
            let cleaned = Self.sanitize(content)
            if cleaned.isEmpty {
                completion(.failure(ClientError.emptyResponse))
            } else {
                completion(.success(cleaned))
            }
        }
        task.resume()
    }

    /// Pull the assistant text out of either an OpenAI response
    /// (choices[0].message.content) or an Ollama-native one (message.content).
    static func extractContent(_ data: Data) -> String? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        if let choices = obj["choices"] as? [[String: Any]],
           let message = choices.first?["message"] as? [String: Any],
           let content = message["content"] as? String {
            return content
        }
        if let message = obj["message"] as? [String: Any],
           let content = message["content"] as? String {
            return content
        }
        return nil
    }

    /// Strip whitespace and accidental wrapping quotes / code fences the model
    /// sometimes adds despite instructions.
    static func sanitize(_ s: String) -> String {
        var t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasPrefix("```") {
            t = t.replacingOccurrences(of: "```", with: "")
                 .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if (t.hasPrefix("\"") && t.hasSuffix("\"")) ||
           (t.hasPrefix("“") && t.hasSuffix("”")) {
            t = String(t.dropFirst().dropLast())
        }
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
