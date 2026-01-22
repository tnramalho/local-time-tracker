import SwiftUI
import Charts

struct DailyReportView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var selectedDate: Date = Date()
    @State private var projectSummaries: [ProjectTimeSummary] = []
    @State private var activities: [Activity] = []

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)

                Spacer()

                Text("Daily Report")
                    .font(.headline)

                Spacer()

                Button("Export CSV") {
                    exportCSV()
                }
            }
            .padding()

            Divider()

            // Date Picker
            HStack {
                Button(action: { changeDate(by: -1) }) {
                    Image(systemName: "chevron.left")
                }

                DatePicker("", selection: $selectedDate, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)

                Button(action: { changeDate(by: 1) }) {
                    Image(systemName: "chevron.right")
                }
                .disabled(Calendar.current.isDateInToday(selectedDate))

                Spacer()

                if !Calendar.current.isDateInToday(selectedDate) {
                    Button("Today") {
                        selectedDate = Date()
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            // Content
            ScrollView {
                VStack(spacing: 20) {
                    // Summary Stats
                    SummaryStatsView(summaries: projectSummaries)

                    // Pie Chart
                    if !projectSummaries.isEmpty {
                        PieChartView(summaries: projectSummaries)
                            .frame(height: 250)
                    }

                    // Project Breakdown
                    ProjectBreakdownView(summaries: projectSummaries)

                    // Timeline
                    TimelineChart(activities: activities)
                        .frame(height: 100)
                }
                .padding()
            }
        }
        .frame(width: 500, height: 600)
        .onChange(of: selectedDate) { _, _ in
            loadData()
        }
        .onAppear {
            loadData()
        }
    }

    private func changeDate(by days: Int) {
        if let newDate = Calendar.current.date(byAdding: .day, value: days, to: selectedDate) {
            selectedDate = newDate
        }
    }

    private func loadData() {
        projectSummaries = appState.getProjectTimeSummaries(for: selectedDate)

        do {
            activities = try appState.activityStore.fetchActivities(for: selectedDate)
        } catch {
            print("Failed to load activities: \(error)")
            activities = []
        }
    }

    private func exportCSV() {
        let csv = generateCSV()

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "timetrack-\(formatDate(selectedDate)).csv"

        panel.begin { result in
            if result == .OK, let url = panel.url {
                do {
                    try csv.write(to: url, atomically: true, encoding: .utf8)
                    NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
                } catch {
                    print("Failed to save CSV: \(error)")
                }
            }
        }
    }

    private func generateCSV() -> String {
        var lines = ["Project,Duration (seconds),Duration (formatted),Percentage"]

        for summary in projectSummaries {
            let line = "\(summary.project.name),\(summary.totalSeconds),\(summary.formattedDuration),\(String(format: "%.1f", summary.percentage))%"
            lines.append(line)
        }

        return lines.joined(separator: "\n")
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

struct SummaryStatsView: View {
    let summaries: [ProjectTimeSummary]

    private var totalSeconds: Int {
        summaries.reduce(0) { $0 + $1.totalSeconds }
    }

    private var formattedTotal: String {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60

        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        } else {
            return String(format: "%dm", minutes)
        }
    }

    var body: some View {
        HStack(spacing: 20) {
            StatBox(title: "Total Time", value: formattedTotal, icon: "clock.fill")
            StatBox(title: "Projects", value: "\(summaries.count)", icon: "folder.fill")
            StatBox(title: "Activities", value: "-", icon: "list.bullet")
        }
    }
}

struct StatBox: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)

            Text(value)
                .font(.title2)
                .fontWeight(.semibold)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(10)
    }
}

struct PieChartView: View {
    let summaries: [ProjectTimeSummary]

    var body: some View {
        Chart(summaries) { summary in
            SectorMark(
                angle: .value("Time", summary.totalSeconds),
                innerRadius: .ratio(0.5),
                angularInset: 1.0
            )
            .foregroundStyle(Color(hex: summary.project.color))
            .annotation(position: .overlay) {
                if summary.percentage > 10 {
                    Text("\(Int(summary.percentage))%")
                        .font(.caption2)
                        .foregroundColor(.white)
                        .fontWeight(.bold)
                }
            }
        }
    }
}

struct ProjectBreakdownView: View {
    let summaries: [ProjectTimeSummary]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Project Breakdown")
                .font(.headline)

            ForEach(summaries) { summary in
                HStack {
                    Circle()
                        .fill(Color(hex: summary.project.color))
                        .frame(width: 12, height: 12)

                    if let icon = summary.project.icon {
                        Image(systemName: icon)
                            .font(.caption)
                            .foregroundColor(Color(hex: summary.project.color))
                    }

                    Text(summary.project.name)

                    Spacer()

                    Text(summary.formattedDuration)
                        .monospacedDigit()

                    Text(String(format: "%.1f%%", summary.percentage))
                        .foregroundColor(.secondary)
                        .frame(width: 50, alignment: .trailing)
                }

                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 6)
                            .cornerRadius(3)

                        Rectangle()
                            .fill(Color(hex: summary.project.color))
                            .frame(width: geometry.size.width * CGFloat(summary.percentage / 100), height: 6)
                            .cornerRadius(3)
                    }
                }
                .frame(height: 6)
            }
        }
    }
}

#Preview {
    DailyReportView()
        .environmentObject(AppState())
}
