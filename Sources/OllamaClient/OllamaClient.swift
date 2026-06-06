import Foundation

// MARK: - OllamaError

public enum OllamaError: Error, Sendable, LocalizedError {
    case invalidURL
    case httpError(Int)
    case invalidResponse
    case unavailable

    public var errorDescription: String? {
        switch self {
        case .invalidURL:        return "Invalid Ollama URL."
        case .httpError(let c): return "Ollama HTTP error \(c)."
        case .invalidResponse:  return "Ollama returned an unexpected response format."
        case .unavailable:      return "Ollama is not running."
        }
    }
}

// MARK: - OllamaModel

public struct OllamaModel: Sendable, Identifiable, Hashable {
    public var id: String { name }
    public let name: String
    public let size: Int64

    public init(name: String, size: Int64 = 0) {
        self.name = name
        self.size = size
    }
}

// MARK: - OllamaClient

/// Async/await client for a local Ollama instance.
///
/// All network calls use Swift concurrency — no callback APIs, no `DispatchQueue.main.async`.
/// Designed to be the single network layer shared by FOKS_BLOOMBERG and System_Org.
///
/// Usage:
/// ```swift
/// let client = OllamaClient()
/// let available = await client.isAvailable()
/// let models = await client.models()
/// let reply = try await client.generate(model: "llama3.2", prompt: "Hello")
/// ```
public struct OllamaClient: Sendable {
    public let baseURL: URL
    private let session: URLSession

    public init(
        baseURL: URL = URL(string: "http://localhost:11434")!,
        timeoutInterval: TimeInterval = 5
    ) {
        self.baseURL = baseURL
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = timeoutInterval
        self.session = URLSession(configuration: config)
    }

    // MARK: - Availability

    /// Returns `true` when Ollama is reachable and has at least one model loaded.
    public func isAvailable() async -> Bool {
        await !models().isEmpty
    }

    // MARK: - Models

    /// Lists all locally available models.
    public func models() async -> [OllamaModel] {
        guard let url = URL(string: "/api/tags", relativeTo: baseURL) else { return [] }
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        guard
            let (data, response) = try? await session.data(for: request),
            let http = response as? HTTPURLResponse,
            http.statusCode == 200,
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let rawModels = json["models"] as? [[String: Any]]
        else { return [] }
        return rawModels.compactMap { dict -> OllamaModel? in
            guard let name = dict["name"] as? String else { return nil }
            return OllamaModel(name: name, size: dict["size"] as? Int64 ?? 0)
        }
    }

    // MARK: - Generate (non-streaming)

    /// Sends a prompt and returns the complete response text.
    /// - Parameters:
    ///   - model: Model name, e.g. `"llama3.2"`.
    ///   - prompt: The user prompt.
    ///   - system: Optional system prompt.
    ///   - timeout: Request timeout in seconds (default 120).
    public func generate(
        model: String,
        prompt: String,
        system: String? = nil,
        timeout: TimeInterval = 120
    ) async throws -> String {
        let url = try endpoint("/api/generate")
        var body: [String: Any] = ["model": model, "prompt": prompt, "stream": false]
        if let system { body["system"] = system }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = timeout

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw OllamaError.httpError((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let text = json["response"] as? String
        else { throw OllamaError.invalidResponse }
        return text
    }

    // MARK: - Generate (streaming)

    /// Streams response tokens as an `AsyncThrowingStream<String, Error>`.
    ///
    /// Each yielded `String` is a single token fragment. Collect them yourself:
    /// ```swift
    /// var full = ""
    /// for try await token in client.generateStream(model: "llama3.2", prompt: text) {
    ///     full += token
    ///     await MainActor.run { label.stringValue = full }
    /// }
    /// ```
    public func generateStream(
        model: String,
        prompt: String,
        system: String? = nil
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let url = try self.endpoint("/api/generate")
                    var body: [String: Any] = ["model": model, "prompt": prompt, "stream": true]
                    if let system { body["system"] = system }

                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)
                    request.timeoutInterval = 300

                    let (stream, response) = try await self.session.bytes(for: request)
                    guard
                        let http = response as? HTTPURLResponse,
                        http.statusCode == 200
                    else {
                        continuation.finish(
                            throwing: OllamaError.httpError(
                                (response as? HTTPURLResponse)?.statusCode ?? -1
                            )
                        )
                        return
                    }

                    for try await line in stream.lines {
                        guard !line.isEmpty else { continue }
                        guard
                            let data = line.data(using: .utf8),
                            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                            let token = json["response"] as? String
                        else { continue }
                        continuation.yield(token)
                        if json["done"] as? Bool == true { break }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Helpers

    private func endpoint(_ path: String) throws -> URL {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw OllamaError.invalidURL
        }
        return url
    }
}
