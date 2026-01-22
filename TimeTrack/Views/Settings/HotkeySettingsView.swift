import SwiftUI

struct HotkeySettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var isRecording = false

    var body: some View {
        Form {
            Section("Voice Input Hotkey") {
                HStack {
                    Text("Current hotkey:")
                    Spacer()

                    if isRecording {
                        Text("Press new hotkey...")
                            .foregroundColor(.blue)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(6)
                    } else {
                        Text(appState.hotkeyService.voiceHotkey.displayString)
                            .font(.system(.body, design: .monospaced))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(6)
                    }
                }

                HStack {
                    Button(isRecording ? "Cancel" : "Record New Hotkey") {
                        if isRecording {
                            appState.hotkeyService.cancelRecordingHotkey()
                            isRecording = false
                        } else {
                            isRecording = true
                            appState.hotkeyService.startRecordingHotkey { newConfig in
                                if let config = newConfig {
                                    appState.hotkeyService.voiceHotkey = config
                                }
                                isRecording = false
                            }
                        }
                    }

                    Spacer()

                    Button("Reset to Default") {
                        appState.hotkeyService.voiceHotkey = .defaultVoiceHotkey
                    }
                    .foregroundColor(.secondary)
                }
            }

            Section("Tips") {
                VStack(alignment: .leading, spacing: 8) {
                    HotkeyTip(
                        icon: "keyboard",
                        text: "The hotkey works globally, even when TimeTrack is in the background"
                    )

                    HotkeyTip(
                        icon: "mic.fill",
                        text: "Press the hotkey to start voice input, speak a project name, and it will auto-categorize"
                    )

                    HotkeyTip(
                        icon: "command",
                        text: "Use at least one modifier key (Cmd, Shift, Option, or Control)"
                    )
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
    }
}

struct HotkeyTip: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 20)

            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    HotkeySettingsView()
        .environmentObject(AppState())
}
