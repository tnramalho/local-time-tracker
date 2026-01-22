import Foundation

struct OllamaCategorizationResult: Codable {
    let project: String
    let confidence: Double
}

struct OllamaGenerateRequest: Codable {
    let model: String
    let prompt: String
    let stream: Bool
    let format: String?

    init(model: String, prompt: String, stream: Bool = false, format: String? = "json") {
        self.model = model
        self.prompt = prompt
        self.stream = stream
        self.format = format
    }
}

struct OllamaGenerateResponse: Codable {
    let model: String
    let response: String
    let done: Bool
}

final class OllamaService: ObservableObject {
    @Published var isAvailable: Bool = false
    @Published var currentModel: String = "llama3.2:3b"
    @Published var baseURL: URL = URL(string: "http://localhost:11434")!

    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        session = URLSession(configuration: config)

        Task {
            await checkAvailability()
        }
    }

    // MARK: - Availability

    @MainActor
    func checkAvailability() async -> Bool {
        let url = baseURL.appendingPathComponent("api/tags")

        do {
            let (_, response) = try await session.data(from: url)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                isAvailable = true
                return true
            }
        } catch {
            print("Ollama not available: \(error)")
        }

        isAvailable = false
        return false
    }

    // MARK: - Categorization

    func categorize(appName: String, windowTitle: String?, url: String?, availableProjects: [Project]) async -> OllamaCategorizationResult? {
        guard isAvailable else { return nil }

        let projectNames = availableProjects.map { $0.name }.joined(separator: ", ")

        let prompt = """
        Analise esta atividade e categorize no projeto correto.
        Projetos disponíveis: \(projectNames)

        App: \(appName)
        Título: \(windowTitle ?? "N/A")
        URL: \(url ?? "N/A")

        Responda APENAS com JSON no formato: {"project": "nome_do_projeto", "confidence": 0.0-1.0}
        Onde confidence é sua confiança na categorização (0.0 a 1.0).
        Se não tiver certeza, use confidence menor que 0.7.
        O nome do projeto deve ser exatamente como listado acima.
        """

        let request = OllamaGenerateRequest(model: currentModel, prompt: prompt)

        do {
            let apiURL = baseURL.appendingPathComponent("api/generate")
            var urlRequest = URLRequest(url: apiURL)
            urlRequest.httpMethod = "POST"
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.httpBody = try JSONEncoder().encode(request)

            let (data, response) = try await session.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("Ollama categorization failed: bad response")
                return nil
            }

            let ollamaResponse = try JSONDecoder().decode(OllamaGenerateResponse.self, from: data)

            // Parse the JSON response from Ollama
            if let jsonData = ollamaResponse.response.data(using: .utf8) {
                // Try to extract JSON from the response (it might have extra text)
                let cleanedResponse = extractJSON(from: ollamaResponse.response)
                if let cleanedData = cleanedResponse.data(using: .utf8) {
                    let result = try JSONDecoder().decode(OllamaCategorizationResult.self, from: cleanedData)
                    return result
                }
            }
        } catch {
            print("Ollama categorization error: \(error)")
        }

        return nil
    }

    private func extractJSON(from text: String) -> String {
        // Try to find JSON object in the response
        if let start = text.firstIndex(of: "{"),
           let end = text.lastIndex(of: "}") {
            return String(text[start...end])
        }
        return text
    }

    // MARK: - Model Management

    struct OllamaModel: Codable, Identifiable {
        let name: String
        let modifiedAt: String?
        let size: Int64?

        var id: String { name }

        enum CodingKeys: String, CodingKey {
            case name
            case modifiedAt = "modified_at"
            case size
        }
    }

    struct OllamaModelsResponse: Codable {
        let models: [OllamaModel]
    }

    func listModels() async -> [OllamaModel] {
        let url = baseURL.appendingPathComponent("api/tags")

        do {
            let (data, response) = try await session.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return []
            }

            let modelsResponse = try JSONDecoder().decode(OllamaModelsResponse.self, from: data)
            return modelsResponse.models
        } catch {
            print("Failed to list Ollama models: \(error)")
            return []
        }
    }
}

// MARK: - Settings Persistence
extension OllamaService {
    private static let modelKey = "OllamaModel"
    private static let baseURLKey = "OllamaBaseURL"

    func loadSettings() {
        if let model = UserDefaults.standard.string(forKey: Self.modelKey) {
            currentModel = model
        }
        if let urlString = UserDefaults.standard.string(forKey: Self.baseURLKey),
           let url = URL(string: urlString) {
            baseURL = url
        }
    }

    func saveSettings() {
        UserDefaults.standard.set(currentModel, forKey: Self.modelKey)
        UserDefaults.standard.set(baseURL.absoluteString, forKey: Self.baseURLKey)
    }
}
