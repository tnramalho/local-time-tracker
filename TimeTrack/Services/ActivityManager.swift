import Foundation
import Combine

final class ActivityManager: ObservableObject {
    @Published private(set) var currentActivity: Activity?
    @Published private(set) var todayTotalSeconds: Int = 0
    @Published private(set) var isTracking: Bool = false

    private let windowTracker: WindowTracker
    private let activityStore: ActivityStore
    private let categoryEngine: CategoryEngine

    private var cancellables = Set<AnyCancellable>()
    private var heartbeatTimer: Timer?
    private let heartbeatInterval: TimeInterval = 2.0
    private var lastWindowInfo: WindowInfo?

    init(
        windowTracker: WindowTracker,
        activityStore: ActivityStore = ActivityStore(),
        categoryEngine: CategoryEngine
    ) {
        self.windowTracker = windowTracker
        self.activityStore = activityStore
        self.categoryEngine = categoryEngine

        setupBindings()
    }

    private func setupBindings() {
        windowTracker.$currentWindow
            .receive(on: DispatchQueue.main)
            .sink { [weak self] windowInfo in
                self?.handleWindowChange(windowInfo)
            }
            .store(in: &cancellables)
    }

    // MARK: - Tracking Control

    func startTracking() {
        guard !isTracking else { return }

        windowTracker.startTracking()
        startHeartbeat()
        isTracking = true
        updateTodayTotal()

        print("Activity tracking started")
    }

    func stopTracking() {
        guard isTracking else { return }

        windowTracker.stopTracking()
        stopHeartbeat()
        saveCurrentActivity()
        isTracking = false

        print("Activity tracking stopped")
    }

    // MARK: - Heartbeat Pattern

    private func startHeartbeat() {
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: heartbeatInterval, repeats: true) { [weak self] _ in
            self?.heartbeat()
        }
    }

    private func stopHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
    }

    private func heartbeat() {
        guard var activity = currentActivity else { return }

        // Increment duration
        activity.durationSeconds += Int(heartbeatInterval)
        currentActivity = activity

        // Save periodically (every 30 seconds)
        if activity.durationSeconds % 30 == 0 {
            saveCurrentActivity()
        }

        updateTodayTotal()
    }

    // MARK: - Window Change Handling

    private func handleWindowChange(_ newWindowInfo: WindowInfo) {
        guard isTracking else { return }

        // Check if it's a significant change
        if shouldStartNewActivity(for: newWindowInfo) {
            saveCurrentActivity()
            startNewActivity(for: newWindowInfo)
        }

        lastWindowInfo = newWindowInfo
    }

    private func shouldStartNewActivity(for newInfo: WindowInfo) -> Bool {
        guard let current = currentActivity else { return true }

        // Different app = new activity
        if current.appName != newInfo.appName {
            return true
        }

        // Same app but significantly different title
        if let oldTitle = current.windowTitle,
           let newTitle = newInfo.windowTitle,
           !titlesAreSimilar(oldTitle, newTitle) {
            return true
        }

        // Different URL = new activity
        if current.url != newInfo.url && newInfo.url != nil {
            return true
        }

        return false
    }

    private func titlesAreSimilar(_ title1: String, _ title2: String) -> Bool {
        // Simple similarity check - can be improved
        // Consider titles similar if they share the same project/context
        let t1 = title1.lowercased()
        let t2 = title2.lowercased()

        // If one contains the other
        if t1.contains(t2) || t2.contains(t1) {
            return true
        }

        // If they share significant words
        let words1 = Set(t1.split(separator: " ").filter { $0.count > 3 })
        let words2 = Set(t2.split(separator: " ").filter { $0.count > 3 })
        let intersection = words1.intersection(words2)

        return intersection.count >= 2
    }

    private func startNewActivity(for windowInfo: WindowInfo) {
        var activity = Activity(
            timestamp: Date(),
            durationSeconds: 0,
            appName: windowInfo.appName,
            appBundleId: windowInfo.appBundleId,
            windowTitle: windowInfo.windowTitle,
            url: windowInfo.url
        )

        // Set activity immediately so time counting starts
        currentActivity = activity

        // Try to categorize asynchronously
        Task { @MainActor in
            if let result = await categoryEngine.categorize(
                appName: windowInfo.appName,
                windowTitle: windowInfo.windowTitle,
                url: windowInfo.url
            ) {
                // Update the current activity with categorization
                if var current = currentActivity,
                   current.appName == windowInfo.appName {
                    current.projectId = result.projectId
                    current.aiConfidence = result.confidence
                    currentActivity = current
                    print("🏷️ Categorized \(windowInfo.appName) -> \(result.projectId)")
                }
            }
        }
    }

    private func saveCurrentActivity() {
        guard var activity = currentActivity, activity.durationSeconds > 0 else { return }

        do {
            if activity.id != nil {
                // Update existing
                try activityStore.updateDuration(for: activity.id!, duration: activity.durationSeconds)
            } else {
                // Insert new
                try activityStore.save(&activity)
                currentActivity = activity
            }
        } catch {
            print("Failed to save activity: \(error)")
        }
    }

    // MARK: - Manual Categorization

    func setProject(_ projectId: String, note: String? = nil) {
        guard var activity = currentActivity else { return }

        activity.projectId = projectId
        activity.isManual = true
        activity.manualNote = note
        activity.aiConfidence = 1.0

        currentActivity = activity

        if let id = activity.id {
            try? activityStore.setProject(for: id, projectId: projectId, confidence: 1.0)
        }
    }

    func clearProject() {
        guard var activity = currentActivity else { return }

        activity.projectId = nil
        activity.isManual = false
        activity.manualNote = nil
        activity.aiConfidence = nil

        currentActivity = activity

        if let id = activity.id {
            try? activityStore.setProject(for: id, projectId: nil, confidence: nil)
        }
    }

    // MARK: - Statistics

    func updateTodayTotal() {
        do {
            var total = try activityStore.totalTimeToday()
            if let current = currentActivity {
                total += current.durationSeconds
            }
            todayTotalSeconds = total
        } catch {
            print("Failed to fetch today total: \(error)")
        }
    }

    var formattedTodayTotal: String {
        let hours = todayTotalSeconds / 3600
        let minutes = (todayTotalSeconds % 3600) / 60

        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        } else {
            return String(format: "%dm", minutes)
        }
    }
}
