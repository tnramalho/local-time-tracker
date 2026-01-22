import SwiftUI

struct CurrentActivityView: View {
    @EnvironmentObject var appState: AppState

    private var currentActivity: Activity? {
        appState.activityManager.currentActivity
    }

    private var currentProject: Project? {
        appState.selectedProject
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Circle()
                    .fill(appState.activityManager.isTracking ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)

                Text(appState.activityManager.isTracking ? "Tracking" : "Paused")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text(appState.activityManager.formattedTodayTotal)
                    .font(.headline)
                    .monospacedDigit()
            }

            // Current App
            if let activity = currentActivity {
                HStack(spacing: 10) {
                    // App icon
                    if let bundleId = activity.appBundleId,
                       let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId),
                       let icon = NSWorkspace.shared.icon(forFile: appURL.path) as NSImage? {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 32, height: 32)
                    } else {
                        Image(systemName: "app.fill")
                            .font(.title)
                            .frame(width: 32, height: 32)
                            .foregroundColor(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(activity.appName)
                            .font(.headline)
                            .lineLimit(1)

                        if let title = activity.windowTitle, !title.isEmpty {
                            Text(title)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                }

                // Current Project
                HStack {
                    if let project = currentProject {
                        ProjectBadge(project: project)
                    } else {
                        Text("Uncategorized")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .cornerRadius(4)
                    }

                    Spacer()

                    // Duration
                    Text(activity.formattedDuration)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundColor(.secondary)
                }
            } else {
                VStack(spacing: 8) {
                    Text("No activity detected")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // Show hint if no accessibility permission
                    if !appState.windowTracker.isAccessibilityEnabled {
                        Button("Grant Accessibility Permission") {
                            appState.windowTracker.requestAccessibilityPermission()
                        }
                        .font(.caption)
                        .foregroundColor(.orange)
                    }
                }
            }
        }
    }
}

struct ProjectBadge: View {
    let project: Project

    var body: some View {
        HStack(spacing: 4) {
            if let icon = project.icon {
                Image(systemName: icon)
                    .font(.caption2)
            }
            Text(project.name)
                .font(.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(Color(hex: project.color).opacity(0.2))
        .foregroundColor(Color(hex: project.color))
        .cornerRadius(4)
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    CurrentActivityView()
        .environmentObject(AppState())
        .frame(width: 280)
        .padding()
}
