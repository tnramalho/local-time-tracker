import SwiftUI
import AppKit

// MARK: - Notification Names for Window Opening
extension Notification.Name {
    static let openQuickPicker = Notification.Name("openQuickPicker")
    static let openDailyReport = Notification.Name("openDailyReport")
}

// MARK: - Window Manager for opening windows from non-view code
@MainActor
final class WindowManager {
    static let shared = WindowManager()

    private init() {}

    func openQuickPicker() {
        NotificationCenter.default.post(name: .openQuickPicker, object: nil)
    }

    func openDailyReport() {
        NotificationCenter.default.post(name: .openDailyReport, object: nil)
    }
}

// MARK: - Quick Picker Window (for Cmd+Shift+M hotkey)
struct QuickPickerWindow: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundColor(.accentColor)
                Text("Quick Categorize")
                    .font(.headline)
                Spacer()
                Text("⌘⇧M")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(4)
            }

            // Current activity info
            if let activity = appState.activityManager.currentActivity {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(activity.appName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        if let title = activity.windowTitle {
                            Text(title)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    if let project = appState.selectedProject {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color(hex: project.color))
                                .frame(width: 8, height: 8)
                            Text(project.name)
                                .font(.caption)
                                .foregroundColor(Color(hex: project.color))
                        }
                    }
                }
                .padding(8)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
            }

            Divider()

            // Projects grid
            Text("Select a project:")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(appState.projects) { project in
                    QuickPickerProjectButton(
                        project: project,
                        isSelected: appState.selectedProject?.id == project.id
                    ) {
                        appState.setCurrentProject(project)
                        dismiss()
                    }
                }
            }

            // Clear button
            Button(action: {
                appState.activityManager.clearProject()
                dismiss()
            }) {
                HStack {
                    Image(systemName: "xmark.circle")
                    Text("Clear Category")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(16)
        .frame(width: 320)
        .background(VisualEffectBlur())
    }
}

struct QuickPickerProjectButton: View {
    let project: Project
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color(hex: project.color))
                    .frame(width: 10, height: 10)

                if let icon = project.icon {
                    Image(systemName: icon)
                        .font(.caption)
                }
                Text(project.name)
                    .font(.subheadline)
                    .lineLimit(1)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption)
                        .foregroundColor(Color(hex: project.color))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(quickPickerBackgroundColor)
            .foregroundColor(quickPickerForegroundColor)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color(hex: project.color) : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var quickPickerBackgroundColor: Color {
        if isSelected {
            return Color(hex: project.color).opacity(0.25)
        } else if isHovered {
            return Color(hex: project.color).opacity(0.15)
        } else {
            return Color.secondary.opacity(0.1)
        }
    }

    private var quickPickerForegroundColor: Color {
        if isSelected {
            return Color(hex: project.color)
        }
        return .primary
    }
}

struct VisualEffectBlur: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.state = .active
        view.material = .hudWindow
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

// MARK: - Quick Category Picker (embedded in menu bar)
struct QuickCategoryPicker: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick Categorize")
                .font(.caption)
                .foregroundColor(.secondary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 6) {
                ForEach(appState.projects.prefix(6)) { project in
                    ProjectButton(
                        project: project,
                        isSelected: appState.selectedProject?.id == project.id
                    ) {
                        appState.setCurrentProject(project)
                    }
                }
            }
        }
    }
}

struct ProjectButton: View {
    let project: Project
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon = project.icon {
                    Image(systemName: icon)
                        .font(.caption)
                }
                Text(project.name)
                    .font(.caption)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color(hex: project.color) : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var backgroundColor: Color {
        if isSelected {
            return Color(hex: project.color).opacity(0.3)
        } else if isHovered {
            return Color(hex: project.color).opacity(0.15)
        } else {
            return Color(hex: project.color).opacity(0.1)
        }
    }

    private var foregroundColor: Color {
        Color(hex: project.color)
    }
}

#Preview {
    QuickCategoryPicker()
        .environmentObject(AppState())
        .frame(width: 280)
        .padding()
}
