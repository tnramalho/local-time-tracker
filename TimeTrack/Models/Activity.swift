import Foundation
import GRDB

struct Activity: Identifiable, Codable, Equatable {
    var id: Int64?
    var timestamp: Date
    var durationSeconds: Int
    var appName: String
    var appBundleId: String?
    var windowTitle: String?
    var url: String?
    var projectId: String?
    var isManual: Bool
    var manualNote: String?
    var aiConfidence: Double?

    init(
        id: Int64? = nil,
        timestamp: Date = Date(),
        durationSeconds: Int = 0,
        appName: String,
        appBundleId: String? = nil,
        windowTitle: String? = nil,
        url: String? = nil,
        projectId: String? = nil,
        isManual: Bool = false,
        manualNote: String? = nil,
        aiConfidence: Double? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.durationSeconds = durationSeconds
        self.appName = appName
        self.appBundleId = appBundleId
        self.windowTitle = windowTitle
        self.url = url
        self.projectId = projectId
        self.isManual = isManual
        self.manualNote = manualNote
        self.aiConfidence = aiConfidence
    }

    var formattedDuration: String {
        let hours = durationSeconds / 3600
        let minutes = (durationSeconds % 3600) / 60
        let seconds = durationSeconds % 60

        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%dm %02ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }
}

// MARK: - GRDB Support
extension Activity: FetchableRecord, MutablePersistableRecord {
    static var databaseTableName: String { "activities" }

    enum Columns: String, ColumnExpression {
        case id
        case timestamp
        case durationSeconds = "duration_seconds"
        case appName = "app_name"
        case appBundleId = "app_bundle_id"
        case windowTitle = "window_title"
        case url
        case projectId = "project_id"
        case isManual = "is_manual"
        case manualNote = "manual_note"
        case aiConfidence = "ai_confidence"
    }

    init(row: Row) {
        id = row[Columns.id]
        timestamp = row[Columns.timestamp]
        durationSeconds = row[Columns.durationSeconds]
        appName = row[Columns.appName]
        appBundleId = row[Columns.appBundleId]
        windowTitle = row[Columns.windowTitle]
        url = row[Columns.url]
        projectId = row[Columns.projectId]
        isManual = row[Columns.isManual]
        manualNote = row[Columns.manualNote]
        aiConfidence = row[Columns.aiConfidence]
    }

    func encode(to container: inout PersistenceContainer) {
        container[Columns.id] = id
        container[Columns.timestamp] = timestamp
        container[Columns.durationSeconds] = durationSeconds
        container[Columns.appName] = appName
        container[Columns.appBundleId] = appBundleId
        container[Columns.windowTitle] = windowTitle
        container[Columns.url] = url
        container[Columns.projectId] = projectId
        container[Columns.isManual] = isManual
        container[Columns.manualNote] = manualNote
        container[Columns.aiConfidence] = aiConfidence
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
