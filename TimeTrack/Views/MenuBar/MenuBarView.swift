import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            // Current Activity Section
            CurrentActivityView()
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

            Divider()

            // Voice Input Section (if active)
            if appState.isVoiceInputActive {
                VoiceInputView()
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)

                Divider()
            }

            // Status Message
            if let message = appState.statusMessage {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                    Text(message)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)

                Divider()
            }

            // Quick Project Picker
            QuickCategoryPicker()
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            Divider()

            // Mini Stats
            MiniStatsView()
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            Divider()

            // Actions
            VStack(spacing: 4) {
                MenuButton(title: "Voice Input", icon: "mic.fill", shortcut: appState.hotkeyService.voiceHotkey.displayString) {
                    appState.toggleVoiceInput()
                }

                MenuButton(title: appState.isTrackingPaused ? "Resume Tracking" : "Pause Tracking",
                          icon: appState.isTrackingPaused ? "play.fill" : "pause.fill") {
                    appState.toggleTracking()
                }

                MenuButton(title: "Daily Report", icon: "chart.pie.fill") {
                    openWindow(id: "daily-report")
                }

                MenuButton(title: "Settings", icon: "gear") {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Quit
            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                HStack {
                    Text("Quit TimeTrack")
                    Spacer()
                    Text("⌘Q")
                        .foregroundColor(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(width: 280)
    }
}

struct MenuButton: View {
    let title: String
    let icon: String
    var shortcut: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .frame(width: 20)
                Text(title)
                Spacer()
                if let shortcut = shortcut {
                    Text(shortcut)
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 4)
    }
}

#Preview {
    MenuBarView()
        .environmentObject(AppState())
}
