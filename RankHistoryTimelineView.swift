import SwiftUI
import CoreData
import Charts

/// A player's journey through the ranks in one season (the current one unless `season` is
/// given): RP after every ranked game with the tier boundaries drawn in, their stats and
/// averages, and that season's rank changes. Past seasons are reached from Season History.
struct RankHistoryTimelineView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var player: Player
    /// nil = the active season.
    var season: Season? = nil

    @State private var journey: RankJourney?
    @State private var seasonName = ""
    @State private var rankChanges: [RankChangeRow] = []
    @State private var stats: SeasonStats = .empty
    @State private var nightsAttended = 0
    @State private var finish: SeasonResult?
    @State private var isPastSeason = false
    @State private var hasHistory = false

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
                    SeasonStatsCard(stats: stats, nightsAttended: nightsAttended)
                    Divider().padding(.vertical, 4)
                    rankChangesSection
                    if season == nil && hasHistory {
                        NavigationLink(value: DashboardRoute.seasonHistory(player: player)) {
                            Label("Past Seasons", systemImage: "clock.arrow.circlepath")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .padding(.top, 8)
                        .accessibilityIdentifier("seasonHistoryLink")
                    }
                }

                Spacer()
            }
            .padding()
        }
        .background(Color("AppBackground").ignoresSafeArea())
        .navigationTitle(isPastSeason ? seasonName : "Rank Timeline")
        .onAppear(perform: load)
    }

    // MARK: Season chart

    @ViewBuilder
    private var seasonSection: some View {
        Text(seasonName.isEmpty ? "This Season" : (isPastSeason ? "\(seasonName) (finished)" : seasonName))
            .font(.headline)

        if let finish {
            FinishBadge(result: finish)
        }

        if let journey, journey.points.count >= 2 {
            summary(journey)
            JourneyChart(journey: journey)
                .frame(height: 280)
                .padding(.vertical, 8)
            Text("Each dot is a ranked game: green gained RP, red lost RP. Dashed lines mark where each tier starts.")
                .font(.caption)
                .foregroundColor(.secondary)
        } else {
            Text(isPastSeason ? "No ranked games that season." : "No ranked games yet this season. Your journey fills in after your first game.")
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
        let active = SeasonManager.activeSeason(in: viewContext)
        let target = season ?? active
        isPastSeason = target.map { !$0.isActive } ?? false
        seasonName = target?.name ?? ""
        hasHistory = SeasonManager.allSeasons(in: viewContext).contains { !$0.isActive }

        guard let target else {
            journey = nil; stats = .empty; nightsAttended = 0; finish = nil
            rankChanges = rankChangeRows { $0.season == nil }
            return
        }

        let seasonGames = SeasonHistory.games(of: player, in: target)
        stats = SeasonStats(seasonGames.map(SeasonHistory.line))
        nightsAttended = SeasonHistory.nightsAttended(by: player, in: target)
        finish = isPastSeason ? SeasonHistory.result(of: player, in: target) : nil

        // The journey runs back from the season's final RP: today's RP for the current season,
        // the saved final RP for a finished one.
        let endRP: Int64? = isPastSeason ? finish?.finalRankPoints : player.rankPoints
        if let endRP {
            let steps = seasonGames.compactMap { game -> RankJourney.GameStep? in
                guard let date = game.date else { return nil }
                return RankJourney.GameStep(date: date, rpDelta: game.rpDelta, won: game.won,
                                            award: game.award, isPlacement: game.isPlacement)
            }
            journey = RankJourney(games: steps, currentRP: endRP, seasonStart: target.startDate)
        } else {
            journey = nil
        }

        // Only this season's rank changes. Changes from before seasons existed count toward the
        // first season.
        let isFirstSeason = target.number == (SeasonManager.allSeasons(in: viewContext).last?.number ?? target.number)
        rankChanges = rankChangeRows { $0.season == target || (isFirstSeason && $0.season == nil) }
    }

    private func rankChangeRows(_ include: (RankChange) -> Bool) -> [RankChangeRow] {
        ((player.rankChanges as? Set<RankChange>) ?? [])
            .filter(include)
            .compactMap { change in
                guard let id = change.id, let rank = change.newRank, let date = change.date else { return nil }
                return RankChangeRow(id: id, rank: rank, date: date,
                                     isSeasonReset: change.reason == RankChangeReason.seasonReset.rawValue)
            }
            .sorted { $0.date > $1.date }
    }
}

/// "Finished #3 of 14 · Gold II, 612 RP"
struct FinishBadge: View {
    let result: SeasonResult

    var body: some View {
        let rank = result.finalRank ?? RankSystem.rankName(for: result.finalRankPoints)
        let place = result.position > 0
            ? "Finished #\(result.position) of \(result.rankedPlayerCount)"
            : (result.wasInPlacement ? "Finished in placement" : "Not ranked")
        HStack(spacing: 10) {
            Image(systemName: result.position > 0 && result.position <= 3 ? "trophy.fill" : "flag.checkered")
                .foregroundColor(result.position > 0 && result.position <= 3 ? .yellow : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(place).font(.subheadline).bold()
                Text("\(rank) · \(result.finalRankPoints) RP").font(.caption).foregroundColor(.secondary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("seasonFinish")
    }
}

/// Record, awards, attendance and per-game averages for one season.
struct SeasonStatsCard: View {
    let stats: SeasonStats
    var nightsAttended: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Season Stats").font(.headline)
            if stats.games == 0 {
                Text("No ranked games yet.").foregroundColor(.gray)
            } else {
                HStack {
                    block("Record", "\(stats.wins)–\(stats.losses)")
                    Spacer()
                    block("Win %", "\(Int((stats.winRate * 100).rounded()))%")
                    Spacer()
                    block("MVP", "\(stats.mvps)")
                    Spacer()
                    block("SVP", "\(stats.svps)")
                    Spacer()
                    block("Net RP", "\(stats.netRP >= 0 ? "+" : "")\(stats.netRP)")
                }
                Text("Per game").font(.caption).foregroundColor(.secondary)
                HStack {
                    ForEach(stats.averages.labelled, id: \.0) { item in
                        block(item.0, SeasonStats.format(item.1))
                        if item.0 != "STL" { Spacer() }
                    }
                }
                .accessibilityIdentifier("seasonAverages")
                Text("Totals: \(stats.totals.points) PTS · \(stats.totals.rebounds) REB · \(stats.totals.assists) AST · \(stats.totals.blocks) BLK · \(stats.totals.steals) STL")
                    .font(.caption).foregroundColor(.secondary)
            }
            if nightsAttended > 0 {
                Text("Game nights attended: \(nightsAttended)").font(.caption).foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func block(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2).foregroundColor(.secondary)
            Text(value).font(.subheadline).bold()
        }
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
