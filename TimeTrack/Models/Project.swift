import Foundation
import GRDB

struct Project: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var name: String
    var color: String
    var icon: String?
    var isActive: Bool

    init(id: String = UUID().uuidString, name: String, color: String, icon: String? = nil, isActive: Bool = true) {
        self.id = id
        self.name = name
        self.color = color
        self.icon = icon
        self.isActive = isActive
    }

    static let defaultProjects: [Project] = [
        Project(id: "concepta", name: "Concepta", color: "#007AFF", icon: "building.2"),
        Project(id: "atalho", name: "Atalho", color: "#34C759", icon: "link"),
        Project(id: "remot", name: "Remot", color: "#AF52DE", icon: "network"),
        Project(id: "pessoal", name: "Pessoal", color: "#FFCC00", icon: "person"),
        Project(id: "pesquisa", name: "Pesquisa", color: "#FF2D55", icon: "magnifyingglass"),
        Project(id: "whatsapp", name: "WhatsApp", color: "#25D366", icon: "message")
    ]
}

// MARK: - GRDB Support
extension Project: FetchableRecord, PersistableRecord {
    static var databaseTableName: String { "projects" }

    enum Columns: String, ColumnExpression {
        case id, name, color, icon, isActive = "is_active"
    }

    init(row: Row) {
        id = row[Columns.id]
        name = row[Columns.name]
        color = row[Columns.color]
        icon = row[Columns.icon]
        isActive = row[Columns.isActive]
    }

    func encode(to container: inout PersistenceContainer) {
        container[Columns.id] = id
        container[Columns.name] = name
        container[Columns.color] = color
        container[Columns.icon] = icon
        container[Columns.isActive] = isActive
    }
}
