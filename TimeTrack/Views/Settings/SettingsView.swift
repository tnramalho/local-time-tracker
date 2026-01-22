import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            ProjectsSettingsView()
                .tabItem {
                    Label("Projects", systemImage: "folder")
                }

            RulesSettingsView()
                .tabItem {
                    Label("Rules", systemImage: "list.bullet.rectangle")
                }

            HotkeySettingsView()
                .tabItem {
                    Label("Hotkeys", systemImage: "keyboard")
                }

            OllamaSettingsView()
                .tabItem {
                    Label("AI (Ollama)", systemImage: "brain")
                }

            PermissionsSettingsView()
                .tabItem {
                    Label("Permissions", systemImage: "lock.shield")
                }
        }
        .frame(width: 600, height: 450)
    }
}

// MARK: - Rules Settings View
struct RulesSettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var rules: [CategoryRule] = []
    @State private var showingAddRule = false
    @State private var editingRule: CategoryRule?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Categorization Rules")
                    .font(.headline)
                Spacer()
                Button(action: { showingAddRule = true }) {
                    Label("Add Rule", systemImage: "plus")
                }
            }
            .padding()

            Divider()

            // Rules List
            if rules.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No rules yet")
                        .font(.headline)
                    Text("Add rules to automatically categorize apps and websites")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(rules) { rule in
                        RuleRow(rule: rule, project: appState.projects.first { $0.id == rule.projectId })
                            .contentShape(Rectangle())
                            .onTapGesture {
                                editingRule = rule
                            }
                            .contextMenu {
                                Button("Edit") { editingRule = rule }
                                Button("Delete", role: .destructive) { deleteRule(rule) }
                            }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            deleteRule(rules[index])
                        }
                    }
                }
            }
        }
        .onAppear { loadRules() }
        .sheet(isPresented: $showingAddRule) {
            RuleEditorSheet(rule: nil, projects: appState.projects) { newRule in
                saveRule(newRule)
            }
        }
        .sheet(item: $editingRule) { rule in
            RuleEditorSheet(rule: rule, projects: appState.projects) { updatedRule in
                saveRule(updatedRule)
            }
        }
    }

    private func loadRules() {
        do {
            rules = try appState.projectStore.fetchRules()
        } catch {
            print("Failed to load rules: \(error)")
        }
    }

    private func saveRule(_ rule: CategoryRule) {
        var mutableRule = rule
        do {
            try appState.projectStore.saveRule(&mutableRule)
            loadRules()
            appState.categoryEngine.refreshCache()
        } catch {
            print("Failed to save rule: \(error)")
        }
    }

    private func deleteRule(_ rule: CategoryRule) {
        guard let id = rule.id else { return }
        do {
            try appState.projectStore.deleteRule(id: id)
            loadRules()
            appState.categoryEngine.refreshCache()
        } catch {
            print("Failed to delete rule: \(error)")
        }
    }
}

struct RuleRow: View {
    let rule: CategoryRule
    let project: Project?

    var body: some View {
        HStack(spacing: 12) {
            // Type icon
            Image(systemName: typeIcon)
                .foregroundColor(.secondary)
                .frame(width: 20)

            // Pattern
            VStack(alignment: .leading, spacing: 2) {
                Text(rule.matchPattern)
                    .font(.body)
                Text(rule.matchType.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Project
            if let project = project {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(hex: project.color))
                        .frame(width: 8, height: 8)
                    Text(project.name)
                        .font(.caption)
                        .foregroundColor(Color(hex: project.color))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(hex: project.color).opacity(0.15))
                .cornerRadius(6)
            }

            // Priority badge
            Text("\(rule.priority)")
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(4)
        }
        .padding(.vertical, 4)
    }

    private var typeIcon: String {
        switch rule.matchType {
        case .app: return "app.badge"
        case .title: return "textformat"
        case .url: return "link"
        }
    }
}

struct RuleEditorSheet: View {
    let rule: CategoryRule?
    let projects: [Project]
    let onSave: (CategoryRule) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var matchType: MatchType = .app
    @State private var matchPattern: String = ""
    @State private var selectedProjectId: String = ""
    @State private var priority: Int = 10

    var body: some View {
        VStack(spacing: 20) {
            Text(rule == nil ? "Add Rule" : "Edit Rule")
                .font(.headline)

            Form {
                // Match Type
                Picker("Match Type", selection: $matchType) {
                    ForEach(MatchType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }

                // Pattern
                TextField("Pattern (e.g., slack, github.com)", text: $matchPattern)

                // Project
                Picker("Project", selection: $selectedProjectId) {
                    Text("Select...").tag("")
                    ForEach(projects) { project in
                        HStack {
                            Circle()
                                .fill(Color(hex: project.color))
                                .frame(width: 8, height: 8)
                            Text(project.name)
                        }
                        .tag(project.id)
                    }
                }

                // Priority
                Stepper("Priority: \(priority)", value: $priority, in: 1...100)
                Text("Lower number = higher priority")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save") {
                    let newRule = CategoryRule(
                        id: rule?.id,
                        priority: priority,
                        matchType: matchType,
                        matchPattern: matchPattern,
                        projectId: selectedProjectId
                    )
                    onSave(newRule)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(matchPattern.isEmpty || selectedProjectId.isEmpty)
            }
        }
        .padding()
        .frame(width: 400, height: 300)
        .onAppear {
            if let rule = rule {
                matchType = rule.matchType
                matchPattern = rule.matchPattern
                selectedProjectId = rule.projectId
                priority = rule.priority
            } else if let firstProject = projects.first {
                selectedProjectId = firstProject.id
            }
        }
    }
}

struct GeneralSettingsView: View {
    @AppStorage("LaunchAtLogin") private var launchAtLogin = false
    @AppStorage("ShowInDock") private var showInDock = false
    @AppStorage("TrackingEnabled") private var trackingEnabled = true

    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Launch TimeTrack at login", isOn: $launchAtLogin)
                Toggle("Show in Dock", isOn: $showInDock)
                    .onChange(of: showInDock) { _, newValue in
                        NSApp.setActivationPolicy(newValue ? .regular : .accessory)
                    }
            }

            Section("Tracking") {
                Toggle("Enable automatic tracking", isOn: $trackingEnabled)
            }

            Section("Data") {
                HStack {
                    Text("Database Location")
                    Spacer()
                    Button("Show in Finder") {
                        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                            .appendingPathComponent("TimeTrack")
                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.path)
                    }
                }

                HStack {
                    Text("Clear old data")
                    Spacer()
                    Button("Clear data older than 30 days") {
                        // Implementation
                    }
                    .foregroundColor(.red)
                }
            }
        }
        .padding()
    }
}

struct PermissionsSettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Form {
            Section("Required Permissions") {
                PermissionRow(
                    title: "Accessibility",
                    description: "Required to read window titles",
                    isGranted: appState.windowTracker.isAccessibilityEnabled,
                    action: {
                        appState.windowTracker.requestAccessibilityPermission()
                    }
                )

                PermissionRow(
                    title: "Speech Recognition",
                    description: "Required for voice commands",
                    isGranted: appState.speechService.authorizationStatus == .authorized,
                    action: {
                        Task {
                            await appState.speechService.requestAuthorization()
                        }
                    }
                )

                PermissionRow(
                    title: "Microphone",
                    description: "Required for voice input",
                    isGranted: true, // Checked with speech
                    action: {}
                )
            }

            Section {
                Button("Open System Preferences") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy")!)
                }
            }
        }
        .padding()
    }
}

struct PermissionRow: View {
    let title: String
    let description: String
    let isGranted: Bool
    let action: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if isGranted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Button("Grant") {
                    action()
                }
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
}
