import Foundation
import GRDB

final class AppDatabase {
    static let shared = AppDatabase()

    private(set) var dbQueue: DatabaseQueue!

    private init() {}

    func setup() throws {
        let fileManager = FileManager.default
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directoryURL = appSupportURL.appendingPathComponent("TimeTrack", isDirectory: true)

        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let databaseURL = directoryURL.appendingPathComponent("timetrack.sqlite")
        print("Database path: \(databaseURL.path)")

        dbQueue = try DatabaseQueue(path: databaseURL.path)
        try migrator.migrate(dbQueue)
        try seedDefaultProjects()
    }

    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        #if DEBUG
        migrator.eraseDatabaseOnSchemaChange = true
        #endif

        migrator.registerMigration("v1_initial") { db in
            // Projects table
            try db.create(table: "projects") { t in
                t.column("id", .text).primaryKey()
                t.column("name", .text).notNull()
                t.column("color", .text).notNull()
                t.column("icon", .text)
                t.column("is_active", .integer).notNull().defaults(to: 1)
            }

            // Activities table
            try db.create(table: "activities") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("timestamp", .datetime).notNull()
                t.column("duration_seconds", .integer).notNull()
                t.column("app_name", .text).notNull()
                t.column("app_bundle_id", .text)
                t.column("window_title", .text)
                t.column("url", .text)
                t.column("project_id", .text).references("projects", onDelete: .setNull)
                t.column("is_manual", .integer).notNull().defaults(to: 0)
                t.column("manual_note", .text)
                t.column("ai_confidence", .double)
            }

            // Create indexes for common queries
            try db.create(index: "activities_timestamp", on: "activities", columns: ["timestamp"])
            try db.create(index: "activities_project", on: "activities", columns: ["project_id"])

            // Categorization rules table
            try db.create(table: "categorization_rules") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("priority", .integer).notNull()
                t.column("match_type", .text).notNull()
                t.column("match_pattern", .text).notNull()
                t.column("project_id", .text).references("projects", onDelete: .cascade)
            }

            try db.create(index: "rules_priority", on: "categorization_rules", columns: ["priority"])
        }

        return migrator
    }

    private func seedDefaultProjects() throws {
        try dbQueue.write { db in
            let count = try Project.fetchCount(db)
            guard count == 0 else { return }

            for project in Project.defaultProjects {
                try project.insert(db)
            }

            // Add some default categorization rules
            let defaultRules: [CategoryRule] = [
                CategoryRule(priority: 10, matchType: .app, matchPattern: "whatsapp", projectId: "whatsapp"),
                CategoryRule(priority: 10, matchType: .title, matchPattern: "whatsapp", projectId: "whatsapp"),
                CategoryRule(priority: 20, matchType: .title, matchPattern: "concepta", projectId: "concepta"),
                CategoryRule(priority: 20, matchType: .url, matchPattern: "concepta", projectId: "concepta"),
                CategoryRule(priority: 30, matchType: .title, matchPattern: "atalho", projectId: "atalho"),
                CategoryRule(priority: 30, matchType: .url, matchPattern: "atalho", projectId: "atalho"),
                CategoryRule(priority: 40, matchType: .title, matchPattern: "remot", projectId: "remot"),
                CategoryRule(priority: 40, matchType: .url, matchPattern: "remot", projectId: "remot"),
            ]

            for var rule in defaultRules {
                try rule.insert(db)
            }
        }
    }
}

// MARK: - Database Access Helpers
extension AppDatabase {
    func reader() -> DatabaseReader {
        return dbQueue
    }

    func writer() -> DatabaseWriter {
        return dbQueue
    }
}
