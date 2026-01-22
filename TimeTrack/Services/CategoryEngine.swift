import Foundation

struct CategorizationResult {
    let projectId: String
    let confidence: Double
    let source: CategorizationSource
}

enum CategorizationSource {
    case rule
    case ai
    case manual
}

final class CategoryEngine {
    private let projectStore: ProjectStore
    private let ollamaService: OllamaService

    private var cachedRules: [CategoryRule] = []
    private var cachedProjects: [Project] = []

    var minimumAIConfidence: Double = 0.7

    init(projectStore: ProjectStore = ProjectStore(), ollamaService: OllamaService) {
        self.projectStore = projectStore
        self.ollamaService = ollamaService
        // Note: refreshCache() is called in AppState.setup() after database is initialized
    }

    func refreshCache() {
        do {
            cachedRules = try projectStore.fetchRules()
            cachedProjects = try projectStore.fetchAll()
            print("📋 Category cache refreshed: \(cachedRules.count) rules, \(cachedProjects.count) projects")
        } catch {
            print("❌ Failed to refresh category cache: \(error)")
        }
    }

    // MARK: - Categorization

    func categorize(appName: String, windowTitle: String?, url: String?) async -> CategorizationResult? {
        print("🔍 Categorizing: app=\(appName), title=\(windowTitle ?? "nil"), rules=\(cachedRules.count)")

        // First, try rule-based categorization
        if let ruleResult = categorizeByRules(appName: appName, windowTitle: windowTitle, url: url) {
            print("✅ Matched rule -> project: \(ruleResult.projectId)")
            return ruleResult
        }

        // Then, try AI categorization
        if let aiResult = await categorizeByAI(appName: appName, windowTitle: windowTitle, url: url) {
            return aiResult
        }

        return nil
    }

    // MARK: - Rule-based Categorization

    private func categorizeByRules(appName: String, windowTitle: String?, url: String?) -> CategorizationResult? {
        // Sort rules by priority (lower = higher priority)
        let sortedRules = cachedRules.sorted { $0.priority < $1.priority }

        for rule in sortedRules {
            if rule.matches(appName: appName, windowTitle: windowTitle, url: url) {
                return CategorizationResult(
                    projectId: rule.projectId,
                    confidence: 1.0,
                    source: .rule
                )
            }
        }

        return nil
    }

    // MARK: - AI Categorization

    private func categorizeByAI(appName: String, windowTitle: String?, url: String?) async -> CategorizationResult? {
        guard ollamaService.isAvailable else { return nil }

        let result = await ollamaService.categorize(
            appName: appName,
            windowTitle: windowTitle,
            url: url,
            availableProjects: cachedProjects
        )

        guard let result = result else { return nil }

        // Find the project ID by name (case-insensitive)
        guard let project = cachedProjects.first(where: {
            $0.name.lowercased() == result.project.lowercased()
        }) else {
            print("AI returned unknown project: \(result.project)")
            return nil
        }

        // Only accept if confidence is above threshold
        guard result.confidence >= minimumAIConfidence else {
            print("AI confidence too low: \(result.confidence)")
            return nil
        }

        return CategorizationResult(
            projectId: project.id,
            confidence: result.confidence,
            source: .ai
        )
    }

    // MARK: - Project Matching

    func findProject(byName name: String) -> Project? {
        let normalizedName = name.lowercased().trimmingCharacters(in: .whitespaces)

        // Exact match first
        if let exact = cachedProjects.first(where: { $0.name.lowercased() == normalizedName }) {
            return exact
        }

        // Contains match
        if let contains = cachedProjects.first(where: { $0.name.lowercased().contains(normalizedName) || normalizedName.contains($0.name.lowercased()) }) {
            return contains
        }

        // Fuzzy match - check if most characters match
        for project in cachedProjects {
            let projectChars = Set(project.name.lowercased())
            let nameChars = Set(normalizedName)
            let intersection = projectChars.intersection(nameChars)

            if Double(intersection.count) / Double(max(projectChars.count, nameChars.count)) > 0.8 {
                return project
            }
        }

        return nil
    }

    // MARK: - Learning from Manual Categorization

    func learnFromManual(appName: String, windowTitle: String?, url: String?, projectId: String) {
        // Create rules based on manual categorization
        // This helps improve future automatic categorization
        print("🧠 Learning from manual: app=\(appName), title=\(windowTitle ?? "nil"), url=\(url ?? "nil") -> \(projectId)")

        var rulesToAdd: [CategoryRule] = []

        // 1. ALWAYS create app-based rule (highest priority for learned rules)
        let appRule = CategoryRule(
            priority: 15, // High priority for learned app rules
            matchType: .app,
            matchPattern: appName.lowercased(),
            projectId: projectId
        )
        rulesToAdd.append(appRule)

        // 2. URL-based rule if available
        if let url = url, !url.isEmpty, let host = URL(string: url)?.host {
            let urlRule = CategoryRule(
                priority: 3, // Very high priority for URL rules
                matchType: .url,
                matchPattern: host,
                projectId: projectId
            )
            rulesToAdd.append(urlRule)
        }

        // 3. Title-based rule if meaningful
        if let title = windowTitle, !title.isEmpty {
            let keywords = extractKeywords(from: title)
            if let keyword = keywords.first, keyword.count > 4 {
                let titleRule = CategoryRule(
                    priority: 25,
                    matchType: .title,
                    matchPattern: keyword,
                    projectId: projectId
                )
                rulesToAdd.append(titleRule)
            }
        }

        // Save new rules (skip if similar already exists)
        for var rule in rulesToAdd {
            let existingSimilar = cachedRules.contains { existing in
                existing.matchType == rule.matchType &&
                existing.matchPattern.lowercased() == rule.matchPattern.lowercased()
            }

            if !existingSimilar {
                do {
                    try projectStore.saveRule(&rule)
                    print("✅ Learned: \(rule.matchType.rawValue) '\(rule.matchPattern)' -> \(projectId)")
                } catch {
                    print("❌ Failed to save rule: \(error)")
                }
            }
        }

        // Refresh cache to include new rules
        refreshCache()
    }

    private func extractKeywords(from text: String) -> [String] {
        let words = text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 3 }

        // Filter out common words
        let stopWords = Set(["the", "and", "for", "with", "from", "this", "that", "your", "have", "are", "was", "were", "will", "would", "could", "should"])
        let filtered = words.filter { !stopWords.contains($0) }

        return Array(filtered.prefix(3))
    }
}
