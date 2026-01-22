import SwiftUI

struct MiniStatsView: View {
    @EnvironmentObject var appState: AppState
    @State private var projectSummaries: [ProjectTimeSummary] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Today's Summary")
                .font(.caption)
                .foregroundColor(.secondary)

            if projectSummaries.isEmpty {
                Text("No activity recorded today")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                // Progress bars for each project
                ForEach(projectSummaries.prefix(4)) { summary in
                    MiniProjectStat(summary: summary)
                }

                if projectSummaries.count > 4 {
                    Text("+\(projectSummaries.count - 4) more")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .onAppear {
            loadStats()
        }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in
            loadStats()
        }
    }

    private func loadStats() {
        projectSummaries = appState.getProjectTimeSummaries()
    }
}

struct MiniProjectStat: View {
    let summary: ProjectTimeSummary

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                if let icon = summary.project.icon {
                    Image(systemName: icon)
                        .font(.caption2)
                        .foregroundColor(Color(hex: summary.project.color))
                }

                Text(summary.project.name)
                    .font(.caption)
                    .lineLimit(1)

                Spacer()

                Text(summary.formattedDuration)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundColor(.secondary)
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 4)
                        .cornerRadius(2)

                    Rectangle()
                        .fill(Color(hex: summary.project.color))
                        .frame(width: geometry.size.width * CGFloat(summary.percentage / 100), height: 4)
                        .cornerRadius(2)
                }
            }
            .frame(height: 4)
        }
    }
}

#Preview {
    MiniStatsView()
        .environmentObject(AppState())
        .frame(width: 280)
        .padding()
}
