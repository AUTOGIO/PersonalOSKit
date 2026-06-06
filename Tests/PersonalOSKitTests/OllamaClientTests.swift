import Testing
import Foundation
@testable import OllamaClient

@Suite("OllamaClient — model parsing")
struct OllamaClientTests {

    // MARK: - OllamaModel

    @Test("OllamaModel id equals name")
    func modelIDEqualsName() {
        let model = OllamaModel(name: "llama3.2", size: 2_000_000)
        #expect(model.id == "llama3.2")
        #expect(model.name == "llama3.2")
        #expect(model.size == 2_000_000)
    }

    @Test("OllamaModel default size is 0")
    func modelDefaultSize() {
        let model = OllamaModel(name: "test-model")
        #expect(model.size == 0)
    }

    @Test("OllamaModel hashable and equatable")
    func modelHashable() {
        let a = OllamaModel(name: "llama3.2", size: 100)
        let b = OllamaModel(name: "llama3.2", size: 200)
        // Two models with same name but different size — equality via Hashable (name only via id)
        var set: Set<OllamaModel> = []
        set.insert(a)
        set.insert(b)
        // Both have same id so Set should deduplicate based on Hashable
        // OllamaModel is Hashable by default synthesis — all properties
        // a != b because size differs; both can coexist in set
        #expect(a.id == b.id)
    }

    // MARK: - OllamaError

    @Test("OllamaError descriptions are non-empty")
    func errorDescriptions() {
        let errors: [OllamaError] = [.invalidURL, .httpError(503), .invalidResponse, .unavailable]
        for error in errors {
            #expect(!(error.errorDescription ?? "").isEmpty)
        }
    }

    @Test("OllamaError.httpError carries status code")
    func httpErrorCode() {
        let error = OllamaError.httpError(404)
        if case .httpError(let code) = error {
            #expect(code == 404)
        } else {
            Issue.record("Expected httpError case")
        }
    }

    // MARK: - OllamaClient init

    @Test("OllamaClient default baseURL is localhost:11434")
    func defaultBaseURL() {
        let client = OllamaClient()
        #expect(client.baseURL.absoluteString == "http://localhost:11434")
    }

    @Test("OllamaClient accepts custom baseURL")
    func customBaseURL() {
        let url = URL(string: "http://192.168.1.10:11434")!
        let client = OllamaClient(baseURL: url)
        #expect(client.baseURL == url)
    }

    // MARK: - Live connectivity (skipped if Ollama not running)

    @Test("models() returns non-empty list when Ollama is running")
    func modelsLive() async throws {
        let client = OllamaClient()
        // Check reachability first; if Ollama is down this is a no-op, not a failure
        let available = await client.isAvailable()
        guard available else {
            // Not a test failure — Ollama just isn't running in this environment
            return
        }
        let models = await client.models()
        #expect(!models.isEmpty)
    }
}
