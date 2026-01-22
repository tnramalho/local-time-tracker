import Foundation
import GRDB

final class ProjectStore {
    private let database: AppDatabase

    init(database: AppDatabase = .shared) {
        self.database = database
    }

    // MARK: - Create/Update

    func save(_ project: Project) throws {
        try database.writer().write { db in
            try project.save(db)
        }
    }

    func update(_ project: Project) throws {
        try database.writer().write { db in
            try project.update(db)
        }
    }

    // MARK: - Read

    func fetchAll() throws -> [Project] {
        try database.reader().read { db in
            try Project
                .filter(Project.Columns.isActive == true)
                .order(Project.Columns.name.asc)
                .fetchAll(db)
        }
    }

    func fetch(id: String) throws -> Project? {
        try database.reader().read { db in
            try Project.fetchOne(db, key: id)
        }
    }

    func fetchByName(_ name: String) throws -> Project? {
        try database.reader().read { db in
            try Project
                .filter(Project.Columns.name.lowercased == name.lowercased())
                .fetchOne(db)
        }
    }

    // MARK: - Rules

    func fetchRules() throws -> [CategoryRule] {
        try database.reader().read { db in
            try CategoryRule
                .order(CategoryRule.Columns.priority.asc)
                .fetchAll(db)
        }
    }

    func saveRule(_ rule: inout CategoryRule) throws {
        try database.writer().write { db in
            try rule.save(db)
        }
    }

    func deleteRule(id: Int64) throws {
        try database.writer().write { db in
            _ = try CategoryRule.deleteOne(db, key: id)
        }
    }

    // MARK: - Delete

    func deactivate(id: String) throws {
        try database.writer().write { db in
            try db.execute(
                sql: "UPDATE projects SET is_active = 0 WHERE id = ?",
                arguments: [id]
            )
        }
    }

    func delete(id: String) throws {
        try database.writer().write { db in
            _ = try Project.deleteOne(db, key: id)
        }
    }
}
