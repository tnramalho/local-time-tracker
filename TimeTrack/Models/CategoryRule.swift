import Foundation
import GRDB

enum MatchType: String, Codable, CaseIterable {
    case app = "app"
    case title = "title"
    case url = "url"

    var displayName: String {
        switch self {
        case .app: return "Application"
        case .title: return "Window Title"
        case .url: return "URL"
        }
    }
}

struct CategoryRule: Identifiable, Codable, Equatable {
    var id: Int64?
    var priority: Int
    var matchType: MatchType
    var matchPattern: String
    var projectId: String

    init(
        id: Int64? = nil,
        priority: Int = 100,
        matchType: MatchType,
        matchPattern: String,
        projectId: String
    ) {
        self.id = id
        self.priority = priority
        self.matchType = matchType
        self.matchPattern = matchPattern
        self.projectId = projectId
    }

    func matches(appName: String, windowTitle: String?, url: String?) -> Bool {
        let pattern = matchPattern.lowercased()

        switch matchType {
        case .app:
            return appName.lowercased().contains(pattern)
        case .title:
            return windowTitle?.lowercased().contains(pattern) ?? false
        case .url:
            return url?.lowercased().contains(pattern) ?? false
        }
    }
}

// MARK: - GRDB Support
extension CategoryRule: FetchableRecord, MutablePersistableRecord {
    static var databaseTableName: String { "categorization_rules" }

    enum Columns: String, ColumnExpression {
        case id
        case priority
        case matchType = "match_type"
        case matchPattern = "match_pattern"
        case projectId = "project_id"
    }

    init(row: Row) {
        id = row[Columns.id]
        priority = row[Columns.priority]
        matchType = MatchType(rawValue: row[Columns.matchType]) ?? .app
        matchPattern = row[Columns.matchPattern]
        projectId = row[Columns.projectId]
    }

    func encode(to container: inout PersistenceContainer) {
        container[Columns.id] = id
        container[Columns.priority] = priority
        container[Columns.matchType] = matchType.rawValue
        container[Columns.matchPattern] = matchPattern
        container[Columns.projectId] = projectId
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
