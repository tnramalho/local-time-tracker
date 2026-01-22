import SwiftUI

struct ProjectsSettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedProject: Project?
    @State private var isAddingProject = false
    @State private var editingProject: Project?

    var body: some View {
        HSplitView {
            // Project List
            VStack(spacing: 0) {
                List(appState.projects, selection: $selectedProject) { project in
                    ProjectListRow(project: project)
                        .tag(project)
                        .contextMenu {
                            Button("Edit") {
                                editingProject = project
                            }
                            Divider()
                            Button("Delete", role: .destructive) {
                                appState.deleteProject(project)
                            }
                        }
                }
                .listStyle(.inset)

                Divider()

                HStack {
                    Button(action: { isAddingProject = true }) {
                        Image(systemName: "plus")
                    }

                    Button(action: {
                        if let project = selectedProject {
                            appState.deleteProject(project)
                            selectedProject = nil
                        }
                    }) {
                        Image(systemName: "minus")
                    }
                    .disabled(selectedProject == nil)

                    Spacer()
                }
                .padding(8)
            }
            .frame(minWidth: 180, maxWidth: 250)

            // Project Details
            if let project = selectedProject {
                ProjectDetailView(project: project)
            } else {
                VStack {
                    Text("Select a project")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $isAddingProject) {
            ProjectEditSheet(project: nil) { newProject in
                appState.addProject(newProject)
                isAddingProject = false
            }
        }
        .sheet(item: $editingProject) { project in
            ProjectEditSheet(project: project) { updatedProject in
                appState.updateProject(updatedProject)
                editingProject = nil
            }
        }
    }
}

struct ProjectListRow: View {
    let project: Project

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color(hex: project.color))
                .frame(width: 12, height: 12)

            if let icon = project.icon {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(Color(hex: project.color))
            }

            Text(project.name)
        }
        .padding(.vertical, 2)
    }
}

struct ProjectDetailView: View {
    let project: Project
    @EnvironmentObject var appState: AppState

    var body: some View {
        Form {
            Section("Project Info") {
                LabeledContent("Name", value: project.name)
                LabeledContent("Color") {
                    Circle()
                        .fill(Color(hex: project.color))
                        .frame(width: 20, height: 20)
                }
                if let icon = project.icon {
                    LabeledContent("Icon") {
                        Image(systemName: icon)
                    }
                }
            }

            Section("Statistics") {
                if let summary = appState.getProjectTimeSummaries().first(where: { $0.project.id == project.id }) {
                    LabeledContent("Today", value: summary.formattedDuration)
                } else {
                    LabeledContent("Today", value: "0m")
                }
            }
        }
        .padding()
    }
}

struct ProjectEditSheet: View {
    let project: Project?
    let onSave: (Project) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var color: String = "#007AFF"
    @State private var icon: String = ""

    private let availableColors = [
        "#007AFF", "#34C759", "#AF52DE", "#FFCC00",
        "#FF2D55", "#25D366", "#FF9500", "#5AC8FA"
    ]

    private let availableIcons = [
        "building.2", "link", "network", "person",
        "magnifyingglass", "message", "doc", "folder",
        "star", "heart", "flag", "bookmark"
    ]

    var body: some View {
        VStack(spacing: 20) {
            Text(project == nil ? "Add Project" : "Edit Project")
                .font(.headline)

            Form {
                TextField("Name", text: $name)

                Picker("Color", selection: $color) {
                    ForEach(availableColors, id: \.self) { colorHex in
                        HStack {
                            Circle()
                                .fill(Color(hex: colorHex))
                                .frame(width: 16, height: 16)
                            Text(colorHex)
                        }
                        .tag(colorHex)
                    }
                }

                Picker("Icon", selection: $icon) {
                    Text("None").tag("")
                    ForEach(availableIcons, id: \.self) { iconName in
                        Label(iconName, systemImage: iconName)
                            .tag(iconName)
                    }
                }
            }

            HStack {
                Button("Cancel") {
                    dismiss()
                }

                Spacer()

                Button("Save") {
                    let newProject = Project(
                        id: project?.id ?? UUID().uuidString,
                        name: name,
                        color: color,
                        icon: icon.isEmpty ? nil : icon,
                        isActive: true
                    )
                    onSave(newProject)
                    dismiss()
                }
                .disabled(name.isEmpty)
            }
        }
        .padding()
        .frame(width: 350)
        .onAppear {
            if let project = project {
                name = project.name
                color = project.color
                icon = project.icon ?? ""
            }
        }
    }
}

#Preview {
    ProjectsSettingsView()
        .environmentObject(AppState())
}
