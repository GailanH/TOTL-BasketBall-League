import SwiftUI
import CoreData
import Charts

/// A player's journey through the ranks this season: RP after every ranked game, with the tier
/// boundaries drawn in, plus their rank changes. A player who never changes tier still sees
/// their whole season.
struct RankHistoryTimelineView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var player: Player

    @State private var journey: RankJourney?
    @State private var seasonName = ""
    @State private var rankChanges: [RankChangeRow] = []

    struct RankChangeRow: Identifiable {
        let id: UUID
        let rank: String
        let date: Date
        let isSeasonReset: Bool
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("\(player.username ?? "Player")'s Rank Journey")
                    .font(.title2).bold()

                if !AppConstants.isRanked(player.membership) {
                    Text("The rank timeline is only available for Competitive members.")
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    seasonSection
                    Divider().padding(.vertical, 4)
                    rankChangesSection
                }

                Spacer()
            }
            .padding()
        }
        .background(Color("AppBackground").ignoresSafeArea())
        .navigationTitle("Rank Timeline")
        .onAppear(perform: load)
    }

    // MARK: Season chart

    @ViewBuilder
    private var seasonSection: some View {
        Text(seasonName.isEmpty ? "This Season" : seasonName)
            .font(.headline)

        if let journey, journey.points.count >= 2 {
            summary(journey)
            JourneyChart(journey: journey)
                .frame(height: 280)
                .padding(.vertical, 8)
            Text("Each dot is a ranked game: green gained RP, red lost RP. Dashed lines mark where each tier starts.")
                .font(.caption)
                .foregroundColor(.secondary)
        } else {
            Text("No ranked games yet this season. Your journey fills in after your first game.")
                .foregroundColor(.gray)
        }
    }

    private func summary(_ journey: RankJourney) -> some View {
        let games = journey.points.count - 1
        let wins = journey.points.filter { $0.won == true }.count
        let net = (journey.points.last?.rankPoints ?? 0) - (journey.points.first?.rankPoints ?? 0)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                statBlock("Started", journey.startRank ?? "—")
                Image(systemName: "arrow.right").foregroundColor(.secondary)
                statBlock("Now", journey.currentRank ?? "—")
                Spacer()
                statBlock("Net RP", "\(net >= 0 ? "+" : "")\(net)", color: net >= 0 ? .green : .red)
            }
            Text("\(games) games · \(wins)–\(games - wins) · peak \(journey.peak?.rankPoints ?? 0) RP (\(journey.peak?.rank ?? "—"))")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func statBlock(_ label: String, _ value: String, color: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2).foregroundColor(.secondary)
            Text(value).font(.subheadline).bold().foregroundColor(color)
        }
    }

    // MARK: Rank changes

    @ViewBuilder
    private var rankChangesSection: some View {
        Text("Rank Changes").font(.headline)
        if rankChanges.isEmpty {
            Text("No rank changes yet.")
                .foregroundColor(.gray)
        } else {
            ForEach(rankChanges) { change in
                HStack(spacing: 10) {
                    Circle()
                        .frame(width: 10, height: 10)
                        .foregroundColor(change.isSeasonReset ? .orange : .blue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(change.rank).font(.headline)
                        Text(change.date.formatted(date: .abbreviated, time: .omitted) + (change.isSeasonReset ? " · season reset" : ""))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    // MARK: Data

    private func load() {
        let season = SeasonManager.activeSeason(in: viewContext)
        seasonName = season?.name ?? ""

        let allGames = (player.games as? Set<Game>) ?? []
        let seasonGames = allGames.filter { game in
            guard let gameSeason = game.match?.season else { return false }
            return season != nil && gameSeason == season
        }
        let steps = seasonGames.compactMap { game -> RankJourney.GameStep? in
            guard let date = game.date else { return nil }
            return RankJourney.GameStep(date: date, rpDelta: game.rpDelta, won: game.won,
                                        award: game.award, isPlacement: game.isPlacement)
        }
        journey = RankJourney(games: steps, currentRP: player.rankPoints, seasonStart: season?.startDate)

        rankChanges = ((player.rankChanges as? Set<RankChange>) ?? [])
            .compactMap { change in
                guard let id = change.id, let rank = change.newRank, let date = change.date else { return nil }
                return RankChangeRow(id: id, rank: rank, date: date,
                                     isSeasonReset: change.reason == RankChangeReason.seasonReset.rawValue)
            }
            .sorted { $0.date > $1.date }
    }
}

/// RP over the season. Tier starts are the y-axis gridlines, labelled with the tier name.
/// Deliberately plain Swift Charts (one line series, one point series with unique ids, no
/// annotations) to stay clear of Charts rendering bugs.
private struct JourneyChart: View {
    let journey: RankJourney

    private struct Dot: Identifiable {
        let id: Int
        let date: Date
        let rankPoints: Int64
        let gained: Bool
        let isMVP: Bool
    }

    var body: some View {
        let values = journey.points.map(\.rankPoints)
        let low = max(0, (values.min() ?? 0) - 30)
        let high = (values.max() ?? 100) + 30
        let tierStarts = RankSystem.tiers.dropFirst()
            .map(\.minPoints)
            .filter { $0 >= low && $0 <= high }
        let dots = journey.points.dropFirst().map {
            Dot(id: $0.id, date: $0.date, rankPoints: $0.rankPoints, gained: $0.delta >= 0,
                isMVP: $0.award == Award.mvp.rawValue)
        }

        Chart {
            ForEach(journey.points) { point in
                LineMark(x: .value("Date", point.date), y: .value("RP", point.rankPoints),
                         series: .value("Series", "RP"))
                    .foregroundStyle(Color.blue)
            }
            ForEach(dots) { dot in
                PointMark(x: .value("Date", dot.date), y: .value("RP", dot.rankPoints))
                    .foregroundStyle(dot.gained ? Color.green : Color.red)
                    .symbolSize(dot.isMVP ? 110 : 40)
            }
        }
        .chartYScale(domain: low...high)
        .chartYAxis {
            AxisMarks(position: .leading, values: tierStarts) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                AxisValueLabel {
                    if let rp = value.as(Int64.self) {
                        Text(RankSystem.rankName(for: rp)).font(.caption2)
                    }
                }
            }
            AxisMarks(position: .trailing)
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
            }
        }
    }
}
