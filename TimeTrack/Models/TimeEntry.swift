import Foundation

struct TimeEntry: Identifiable, Equatable {
    let id: String
    let project: Project?
    let totalSeconds: Int
    let startTime: Date
    let endTime: Date
    let activities: [Activity]

    init(project: Project?, activities: [Activity]) {
        self.id = UUID().uuidString
        self.project = project
        self.activities = activities
        self.totalSeconds = activities.reduce(0) { $0 + $1.durationSeconds }
        self.startTime = activities.first?.timestamp ?? Date()
        self.endTime = activities.last?.timestamp ?? Date()
    }

    var formattedDuration: String {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60

        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        } else {
            return String(format: "%dm", minutes)
        }
    }

    var percentage: Double {
        return 0.0 // Will be calculated in context of total time
    }
}

struct DailySummary: Identifiable {
    let id: String
    let date: Date
    let entries: [TimeEntry]
    let totalSeconds: Int

    init(date: Date, entries: [TimeEntry]) {
        self.id = UUID().uuidString
        self.date = date
        self.entries = entries
        self.totalSeconds = entries.reduce(0) { $0 + $1.totalSeconds }
    }

    var formattedTotalTime: String {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60

        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        } else {
            return String(format: "%dm", minutes)
        }
    }

    func percentage(for entry: TimeEntry) -> Double {
        guard totalSeconds > 0 else { return 0 }
        return Double(entry.totalSeconds) / Double(totalSeconds) * 100
    }
}

struct ProjectTimeSummary: Identifiable {
    let id: String
    let project: Project
    let totalSeconds: Int
    let percentage: Double

    var formattedDuration: String {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60

        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        } else {
            return String(format: "%dm", minutes)
        }
    }
}
