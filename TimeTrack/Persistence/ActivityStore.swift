import Foundation
import GRDB
import Combine

final class ActivityStore {
    private let database: AppDatabase

    init(database: AppDatabase = .shared) {
        self.database = database
    }

    // MARK: - Create/Update

    func save(_ activity: inout Activity) throws {
        try database.writer().write { db in
            try activity.save(db)
        }
    }

    func updateDuration(for activityId: Int64, duration: Int) throws {
        try database.writer().write { db in
            try db.execute(
                sql: "UPDATE activities SET duration_seconds = ? WHERE id = ?",
                arguments: [duration, activityId]
            )
        }
    }

    func setProject(for activityId: Int64, projectId: String?, confidence: Double?) throws {
        try database.writer().write { db in
            try db.execute(
                sql: "UPDATE activities SET project_id = ?, ai_confidence = ? WHERE id = ?",
                arguments: [projectId, confidence, activityId]
            )
        }
    }

    // MARK: - Read

    func fetchLatest() throws -> Activity? {
        try database.reader().read { db in
            try Activity
                .order(Activity.Columns.timestamp.desc)
                .fetchOne(db)
        }
    }

    func fetchActivities(for date: Date) throws -> [Activity] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        return try database.reader().read { db in
            try Activity
                .filter(Activity.Columns.timestamp >= startOfDay && Activity.Columns.timestamp < endOfDay)
                .order(Activity.Columns.timestamp.asc)
                .fetchAll(db)
        }
    }

    func fetchActivities(from startDate: Date, to endDate: Date) throws -> [Activity] {
        return try database.reader().read { db in
            try Activity
                .filter(Activity.Columns.timestamp >= startDate && Activity.Columns.timestamp < endDate)
                .order(Activity.Columns.timestamp.asc)
                .fetchAll(db)
        }
    }

    func fetchUncategorizedActivities(limit: Int = 100) throws -> [Activity] {
        return try database.reader().read { db in
            try Activity
                .filter(Activity.Columns.projectId == nil)
                .order(Activity.Columns.timestamp.desc)
                .limit(limit)
                .fetchAll(db)
        }
    }

    // MARK: - Statistics

    func totalTimeToday() throws -> Int {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())

        return try database.reader().read { db in
            let row = try Row.fetchOne(db, sql: """
                SELECT COALESCE(SUM(duration_seconds), 0) as total
                FROM activities
                WHERE timestamp >= ?
                """, arguments: [startOfDay])
            return row?["total"] ?? 0
        }
    }

    func timeByProject(for date: Date) throws -> [(project: Project?, totalSeconds: Int)] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        return try database.reader().read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT
                    p.id, p.name, p.color, p.icon, p.is_active,
                    COALESCE(SUM(a.duration_seconds), 0) as total_seconds
                FROM activities a
                LEFT JOIN projects p ON a.project_id = p.id
                WHERE a.timestamp >= ? AND a.timestamp < ?
                GROUP BY a.project_id
                ORDER BY total_seconds DESC
                """, arguments: [startOfDay, endOfDay])

            return rows.map { row in
                let project: Project? = if let id: String = row["id"] {
                    Project(
                        id: id,
                        name: row["name"],
                        color: row["color"],
                        icon: row["icon"],
                        isActive: row["is_active"]
                    )
                } else {
                    nil
                }
                let totalSeconds: Int = row["total_seconds"]
                return (project, totalSeconds)
            }
        }
    }

    // MARK: - Delete

    func deleteActivities(olderThan days: Int) throws -> Int {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!

        return try database.writer().write { db in
            try Activity
                .filter(Activity.Columns.timestamp < cutoffDate)
                .deleteAll(db)
        }
    }
}
