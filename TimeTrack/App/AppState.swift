import Foundation
import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    // MARK: - Services
    let windowTracker: WindowTracker
    let activityManager: ActivityManager
    let hotkeyService: HotkeyService
    let speechService: SpeechService
    let ollamaService: OllamaService
    let categoryEngine: CategoryEngine

    // MARK: - Stores
    let projectStore: ProjectStore
    let activityStore: ActivityStore

    // MARK: - UI State
    @Published var isVoiceInputActive: Bool = false
    @Published var showingSettings: Bool = false
    @Published var showingReport: Bool = false
    @Published var showingQuickPicker: Bool = false

    @Published var projects: [Project] = []
    @Published var selectedProject: Project?

    @Published var statusMessage: String?
    @Published var isTrackingPaused: Bool = false

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init() {
        // Initialize stores
        projectStore = ProjectStore()
        activityStore = ActivityStore()

        // Initialize services
        windowTracker = WindowTracker()
        ollamaService = OllamaService()
        categoryEngine = CategoryEngine(projectStore: projectStore, ollamaService: ollamaService)
        activityManager = ActivityManager(windowTracker: windowTracker, activityStore: activityStore, categoryEngine: categoryEngine)
        hotkeyService = HotkeyService()
        speechService = SpeechService()

        setupBindings()
        // Note: loadProjects() is called in setup() after database is initialized
    }

    private func setupBindings() {
        // Setup voice hotkey callback (Cmd+Shift+T)
        hotkeyService.onVoiceHotkeyPressed = { [weak self] in
            Task { @MainActor in
                self?.toggleVoiceInput()
            }
        }

        // Setup menu hotkey callback (Cmd+Shift+M)
        hotkeyService.onMenuHotkeyPressed = {
            Task { @MainActor in
                WindowManager.shared.openQuickPicker()
            }
        }

        // Setup speech completion callback
        speechService.onTranscriptionComplete = { [weak self] transcription in
            Task { @MainActor in
                self?.handleVoiceCommand(transcription)
            }
        }

        // Observe activity changes for UI updates
        activityManager.$currentActivity
            .receive(on: DispatchQueue.main)
            .sink { [weak self] activity in
                if let projectId = activity?.projectId {
                    self?.selectedProject = self?.projects.first { $0.id == projectId }
                } else {
                    self?.selectedProject = nil
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Lifecycle

    func setup() async {
        do {
            try AppDatabase.shared.setup()
            loadProjects()
            categoryEngine.refreshCache()

            // Start services
            hotkeyService.startListening()
            activityManager.startTracking()

            // Check Ollama availability
            await ollamaService.checkAvailability()

            print("TimeTrack setup complete")
        } catch {
            print("Failed to setup TimeTrack: \(error)")
        }
    }

    func shutdown() {
        activityManager.stopTracking()
        hotkeyService.stopListening()
    }

    // MARK: - Projects

    func loadProjects() {
        do {
            projects = try projectStore.fetchAll()
            print("📁 Loaded \(projects.count) projects: \(projects.map { $0.name }.joined(separator: ", "))")
        } catch {
            print("❌ Failed to load projects: \(error)")
        }
    }

    func addProject(_ project: Project) {
        do {
            try projectStore.save(project)
            loadProjects()
            categoryEngine.refreshCache()
        } catch {
            print("Failed to add project: \(error)")
        }
    }

    func updateProject(_ project: Project) {
        do {
            try projectStore.update(project)
            loadProjects()
            categoryEngine.refreshCache()
        } catch {
            print("Failed to update project: \(error)")
        }
    }

    func deleteProject(_ project: Project) {
        do {
            try projectStore.deactivate(id: project.id)
            loadProjects()
            categoryEngine.refreshCache()
        } catch {
            print("Failed to delete project: \(error)")
        }
    }

    // MARK: - Voice Input

    func toggleVoiceInput() {
        if isVoiceInputActive {
            stopVoiceInput()
        } else {
            startVoiceInput()
        }
    }

    func startVoiceInput() {
        Task {
            do {
                // Request authorization if needed
                if speechService.authorizationStatus != .authorized {
                    let authorized = await speechService.requestAuthorization()
                    guard authorized else {
                        showStatusMessage("Speech recognition not authorized")
                        return
                    }
                }

                try await speechService.startListening()
                isVoiceInputActive = true
            } catch {
                showStatusMessage("Failed to start voice input: \(error.localizedDescription)")
            }
        }
    }

    func stopVoiceInput() {
        speechService.stopListening()
        isVoiceInputActive = false
    }

    private func handleVoiceCommand(_ transcription: String) {
        isVoiceInputActive = false

        let command = speechService.parseCommand(from: transcription)

        if let projectName = command.projectName,
           let project = categoryEngine.findProject(byName: projectName) {
            setCurrentProject(project, note: command.note)
            showStatusMessage("Categorized as \(project.name)")
        } else if let projectName = command.projectName {
            showStatusMessage("Project '\(projectName)' not found")
        } else {
            showStatusMessage("Couldn't understand: \(transcription)")
        }
    }

    // MARK: - Activity Management

    func setCurrentProject(_ project: Project, note: String? = nil) {
        activityManager.setProject(project.id, note: note)
        selectedProject = project

        // Learn from manual categorization
        if let activity = activityManager.currentActivity {
            categoryEngine.learnFromManual(
                appName: activity.appName,
                windowTitle: activity.windowTitle,
                url: activity.url,
                projectId: project.id
            )
        }
    }

    func toggleTracking() {
        if isTrackingPaused {
            activityManager.startTracking()
        } else {
            activityManager.stopTracking()
        }
        isTrackingPaused.toggle()
    }

    // MARK: - UI Helpers

    func showStatusMessage(_ message: String) {
        statusMessage = message

        // Clear after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            if self?.statusMessage == message {
                self?.statusMessage = nil
            }
        }
    }

    // MARK: - Reports

    func getDailySummary(for date: Date = Date()) -> DailySummary {
        do {
            let activities = try activityStore.fetchActivities(for: date)
            let timeByProject = try activityStore.timeByProject(for: date)

            let entries = timeByProject.map { (project, seconds) in
                let projectActivities = activities.filter { $0.projectId == project?.id }
                return TimeEntry(project: project, activities: projectActivities)
            }

            return DailySummary(date: date, entries: entries)
        } catch {
            print("Failed to get daily summary: \(error)")
            return DailySummary(date: date, entries: [])
        }
    }

    func getProjectTimeSummaries(for date: Date = Date()) -> [ProjectTimeSummary] {
        do {
            let timeByProject = try activityStore.timeByProject(for: date)
            let totalSeconds = timeByProject.reduce(0) { $0 + $1.totalSeconds }

            return timeByProject.compactMap { (project, seconds) in
                guard let project = project else { return nil }
                let percentage = totalSeconds > 0 ? Double(seconds) / Double(totalSeconds) * 100 : 0
                return ProjectTimeSummary(id: project.id, project: project, totalSeconds: seconds, percentage: percentage)
            }
        } catch {
            print("Failed to get project summaries: \(error)")
            return []
        }
    }
}
