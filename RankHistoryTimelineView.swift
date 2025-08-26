import SwiftUI
import CoreData
import Charts

struct RankHistoryTimelineView: View {
    @Environment(\.managedObjectContext) private var viewContext
    let player: Player

    @State private var selectedFilter: FilterOption = .all
    @State private var playerName: String = "Player"
    @State private var rankChangeModels: [RankChangeModel] = []

    struct RankChangeModel: Identifiable, Hashable {
        let id: UUID
        let newRank: String
        let date: Date
    }

    enum FilterOption: String, CaseIterable, Identifiable {
        case all = "All"
        case last5 = "Last 5"
        case last30Days = "Last 30 Days"
        var id: String { self.rawValue }
    }

    var filteredChanges: [RankChangeModel] {
        let sorted = rankChangeModels.sorted { $0.date < $1.date }
        let filtered: [RankChangeModel]

        switch selectedFilter {
        case .all:
            filtered = sorted
        case .last5:
            filtered = Array(sorted.suffix(5))
        case .last30Days:
            let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? .distantPast
            filtered = sorted.filter { $0.date >= cutoff }
        }

        return filtered.filter { RankHistoryTimelineView.rankIndex($0.newRank) != nil }
    }

    var validRankIndices: [Int] {
        filteredChanges.compactMap { RankHistoryTimelineView.rankIndex($0.newRank) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("\(playerName)'s Rank History")
                    .font(.title2).bold()

                Picker("Filter", selection: $selectedFilter) {
                    ForEach(FilterOption.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.bottom)

                if validRankIndices.count >= 2 {
                    ChartViewWrapper(filteredChanges: filteredChanges, validRankIndices: validRankIndices)
                        .frame(height: 250)
                        .padding()
                } else {
                    Text("Not enough unique rank changes to display chart.")
                        .foregroundColor(.gray)
                }

                Divider().padding(.vertical)

                ForEach(filteredChanges) { change in
                    HStack(spacing: 10) {
                        Circle()
                            .frame(width: 10, height: 10)
                            .foregroundColor(.blue)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(change.newRank)
                                .font(.headline)
                            Text(change.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()
            }
            .padding()
        }
        .navigationTitle("Rank Timeline")
        .onAppear {
            loadRankChanges()
        }
    }

    private func loadRankChanges() {
        self.playerName = player.username ?? "Player"

        let rawChanges = (player.rankChanges as? Set<RankChange>) ?? []
        self.rankChangeModels = rawChanges.compactMap { change in
            if let id = change.id, let rank = change.newRank, let date = change.date {
                return RankChangeModel(id: id, newRank: rank, date: date)
            }
            return nil
        }
    }

    // ✅ static so they can be used in ChartViewWrapper
    static func rankIndex(_ rank: String) -> Int? {
        let ranks = [
            "Gold I", "Gold II", "Gold III",
            "Silver I", "Silver II", "Silver III",
            "Bronze I", "Bronze II", "Bronze III",
            "Rookie"
        ]
        return ranks.firstIndex(of: rank).map { ranks.count - $0 }
    }

    static func rankLabel(for index: Int) -> String {
        let ranks = [
            "Gold I", "Gold II", "Gold III",
            "Silver I", "Silver II", "Silver III",
            "Bronze I", "Bronze II", "Bronze III",
            "Rookie"
        ]
        return (index >= 1 && index <= ranks.count) ? ranks[ranks.count - index] : "Unranked"
    }
}

// ✅ Extracted chart into its own struct to prevent memory crash
private struct ChartViewWrapper: View {
    let filteredChanges: [RankHistoryTimelineView.RankChangeModel]
    let validRankIndices: [Int]

    var body: some View {
        let yMin = validRankIndices.min() ?? 1
        let yMax = validRankIndices.max() ?? 10
        let domain = yMin...yMax

        Chart {
            ForEach(filteredChanges) { change in
                if let rankY = RankHistoryTimelineView.rankIndex(change.newRank) {
                    LineMark(
                        x: .value("Date", change.date),
                        y: .value("Rank", rankY)
                    )
                    .interpolationMethod(.monotone)
                    .symbol(Circle())
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [.green, .blue]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                }
            }
        }
        .chartYScale(domain: domain)
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                if let intVal = value.as(Int.self) {
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel {
                        Text(RankHistoryTimelineView.rankLabel(for: intVal))
                    }
                }
            }
        }
    }
}
