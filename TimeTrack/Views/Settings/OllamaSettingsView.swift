import SwiftUI

struct OllamaSettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var models: [OllamaService.OllamaModel] = []
    @State private var isChecking = false
    @State private var baseURLString: String = "http://localhost:11434"
    @State private var selectedModel: String = "llama3.2:3b"

    var body: some View {
        Form {
            Section("Connection") {
                HStack {
                    Text("Status:")
                    Spacer()

                    if isChecking {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else if appState.ollamaService.isAvailable {
                        Label("Connected", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Label("Not Available", systemImage: "xmark.circle.fill")
                            .foregroundColor(.red)
                    }
                }

                HStack {
                    TextField("Base URL", text: $baseURLString)
                        .textFieldStyle(.roundedBorder)

                    Button("Test") {
                        testConnection()
                    }
                }
            }

            Section("Model") {
                if models.isEmpty {
                    Text("No models available")
                        .foregroundColor(.secondary)
                } else {
                    Picker("Model", selection: $selectedModel) {
                        ForEach(models) { model in
                            Text(model.name).tag(model.name)
                        }
                    }
                    .onChange(of: selectedModel) { _, newValue in
                        appState.ollamaService.currentModel = newValue
                        appState.ollamaService.saveSettings()
                    }
                }

                Button("Refresh Models") {
                    loadModels()
                }
            }

            Section("Installation") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("To use AI categorization, you need Ollama installed locally.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    GroupBox {
                        VStack(alignment: .leading, spacing: 8) {
                            CodeBlock(text: "# Install Ollama")
                            CodeBlock(text: "brew install ollama")
                            CodeBlock(text: "")
                            CodeBlock(text: "# Download recommended model")
                            CodeBlock(text: "ollama pull llama3.2:3b")
                            CodeBlock(text: "")
                            CodeBlock(text: "# Start Ollama server")
                            CodeBlock(text: "ollama serve")
                        }
                        .padding(8)
                    }

                    Link("Ollama Documentation", destination: URL(string: "https://ollama.ai")!)
                        .font(.caption)
                }
            }

            Section("Categorization Settings") {
                HStack {
                    Text("Minimum AI Confidence")
                    Spacer()
                    Text("\(Int(appState.categoryEngine.minimumAIConfidence * 100))%")
                        .foregroundColor(.secondary)
                }

                Slider(value: Binding(
                    get: { appState.categoryEngine.minimumAIConfidence },
                    set: { appState.categoryEngine.minimumAIConfidence = $0 }
                ), in: 0.5...1.0, step: 0.05)

                Text("Lower confidence threshold means more automatic categorization, but may be less accurate.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .onAppear {
            baseURLString = appState.ollamaService.baseURL.absoluteString
            selectedModel = appState.ollamaService.currentModel
            loadModels()
        }
    }

    private func testConnection() {
        if let url = URL(string: baseURLString) {
            appState.ollamaService.baseURL = url
        }

        isChecking = true
        Task {
            await appState.ollamaService.checkAvailability()
            await loadModelsAsync()
            isChecking = false
        }
    }

    private func loadModels() {
        Task {
            await loadModelsAsync()
        }
    }

    private func loadModelsAsync() async {
        models = await appState.ollamaService.listModels()
    }
}

struct CodeBlock: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(.caption, design: .monospaced))
            .foregroundColor(text.hasPrefix("#") ? .secondary : .primary)
    }
}

#Preview {
    OllamaSettingsView()
        .environmentObject(AppState())
}
