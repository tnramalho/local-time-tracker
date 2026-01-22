import SwiftUI
import Charts

struct TimelineChart: View {
    let activities: [Activity]

    @State private var hoveredActivity: Activity?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Timeline")
                .font(.headline)

            if activities.isEmpty {
                Text("No activities recorded")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            } else {
                GeometryReader { geometry in
                    let dayStart = Calendar.current.startOfDay(for: activities.first?.timestamp ?? Date())
                    let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart)!
                    let totalSeconds = dayEnd.timeIntervalSince(dayStart)

                    ZStack(alignment: .leading) {
                        // Background with hour markers
                        HStack(spacing: 0) {
                            ForEach(0..<24) { hour in
                                Rectangle()
                                    .fill(hour % 2 == 0 ? Color.gray.opacity(0.1) : Color.gray.opacity(0.05))
                            }
                        }

                        // Activities
                        ForEach(activities, id: \.id) { activity in
                            let startOffset = activity.timestamp.timeIntervalSince(dayStart)
                            let xPosition = CGFloat(startOffset / totalSeconds) * geometry.size.width
                            let width = max(CGFloat(Double(activity.durationSeconds) / totalSeconds) * geometry.size.width, 2)

                            Rectangle()
                                .fill(activityColor(for: activity))
                                .frame(width: width, height: geometry.size.height - 20)
                                .position(x: xPosition + width / 2, y: (geometry.size.height - 20) / 2)
                                .onHover { hovering in
                                    hoveredActivity = hovering ? activity : nil
                                }
                        }

                        // Hour labels
                        VStack {
                            Spacer()
                            HStack {
                                ForEach([0, 6, 12, 18], id: \.self) { hour in
                                    Text(formatHour(hour))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)

                                    if hour < 18 {
                                        Spacer()
                                    }
                                }
                                Text("24")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                // Tooltip
                if let activity = hoveredActivity {
                    HStack {
                        if let projectId = activity.projectId {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 8, height: 8)
                        }

                        Text(activity.appName)
                            .font(.caption)

                        if let title = activity.windowTitle {
                            Text("- \(title)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        Text(activity.formattedDuration)
                            .font(.caption)
                            .monospacedDigit()
                    }
                    .padding(8)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(6)
                }
            }
        }
    }

    private func activityColor(for activity: Activity) -> Color {
        if let projectId = activity.projectId {
            // Try to get project color - for now use default colors
            return projectColorForId(projectId)
        }
        return Color.gray.opacity(0.5)
    }

    private func projectColorForId(_ id: String) -> Color {
        // Map known project IDs to colors
        switch id {
        case "concepta": return Color(hex: "#007AFF")
        case "atalho": return Color(hex: "#34C759")
        case "remot": return Color(hex: "#AF52DE")
        case "pessoal": return Color(hex: "#FFCC00")
        case "pesquisa": return Color(hex: "#FF2D55")
        case "whatsapp": return Color(hex: "#25D366")
        default: return Color.blue
        }
    }

    private func formatHour(_ hour: Int) -> String {
        return String(format: "%02d:00", hour)
    }
}

// MARK: - Activity Timeline Entry
struct ActivityTimelineEntry: Identifiable {
    let id: Int64
    let startTime: Date
    let endTime: Date
    let projectColor: Color
    let appName: String
    let windowTitle: String?

    init(activity: Activity, color: Color) {
        self.id = activity.id ?? 0
        self.startTime = activity.timestamp
        self.endTime = activity.timestamp.addingTimeInterval(Double(activity.durationSeconds))
        self.projectColor = color
        self.appName = activity.appName
        self.windowTitle = activity.windowTitle
    }
}

#Preview {
    TimelineChart(activities: [])
        .frame(height: 100)
        .padding()
}
