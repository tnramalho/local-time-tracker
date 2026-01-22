import SwiftUI

@main
struct TimeTrackApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        // Menu Bar
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
        } label: {
            MenuBarLabel()
                .environmentObject(appState)
        }
        .menuBarExtraStyle(.window)

        // Settings Window
        Settings {
            SettingsView()
                .environmentObject(appState)
        }

        // Report Window
        Window("Daily Report", id: "daily-report") {
            DailyReportView()
                .environmentObject(appState)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)

        // Quick Picker Window (Cmd+Shift+M)
        Window("Quick Picker", id: "quick-picker") {
            QuickPickerWindow()
                .environmentObject(appState)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }

    init() {
        // Setup will be called after appState is created
    }
}

struct MenuBarLabel: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: menuBarIcon)
                .symbolRenderingMode(.hierarchical)

            if let project = appState.selectedProject {
                // Mostrar cor do projeto como indicador
                Circle()
                    .fill(Color(hex: project.color))
                    .frame(width: 8, height: 8)
                Text(project.name)
                    .font(.caption)
            } else if appState.activityManager.currentActivity != nil {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 8, height: 8)
                Text("?")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
        .task {
            await appState.setup()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openQuickPicker)) { _ in
            openWindow(id: "quick-picker")
            NSApp.activate(ignoringOtherApps: true)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openDailyReport)) { _ in
            openWindow(id: "daily-report")
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private var menuBarIcon: String {
        if appState.isVoiceInputActive {
            return "mic.fill"
        } else if appState.activityManager.isTracking {
            return "clock.fill"
        } else {
            return "clock"
        }
    }
}

