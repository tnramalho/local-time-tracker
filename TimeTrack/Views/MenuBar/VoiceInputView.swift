import SwiftUI

struct VoiceInputView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                // Animated microphone
                MicrophoneAnimation(isActive: appState.speechService.isListening)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Listening...")
                        .font(.caption)
                        .fontWeight(.medium)

                    if !appState.speechService.currentTranscription.isEmpty {
                        Text(appState.speechService.currentTranscription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    } else {
                        Text("Say a project name...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .italic()
                    }
                }

                Spacer()

                Button(action: {
                    appState.stopVoiceInput()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Quick suggestions
            if appState.speechService.currentTranscription.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Examples:")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Text("\"Trabalhando no projeto Concepta\"")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .italic()

                    Text("\"Remot fazendo deploy\"")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
        }
        .padding(10)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
    }
}

struct MicrophoneAnimation: View {
    let isActive: Bool

    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 1.0

    var body: some View {
        ZStack {
            // Pulse effect
            Circle()
                .fill(Color.blue.opacity(0.3))
                .frame(width: 36, height: 36)
                .scaleEffect(scale)
                .opacity(opacity)

            // Microphone icon
            Image(systemName: "mic.fill")
                .font(.title2)
                .foregroundColor(.blue)
        }
        .onAppear {
            if isActive {
                startAnimation()
            }
        }
        .onChange(of: isActive) { _, newValue in
            if newValue {
                startAnimation()
            } else {
                stopAnimation()
            }
        }
    }

    private func startAnimation() {
        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
            scale = 1.3
            opacity = 0.5
        }
    }

    private func stopAnimation() {
        withAnimation(.easeOut(duration: 0.2)) {
            scale = 1.0
            opacity = 1.0
        }
    }
}

#Preview {
    VoiceInputView()
        .environmentObject(AppState())
        .frame(width: 280)
        .padding()
}
