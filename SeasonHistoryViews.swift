import SwiftUI
import CoreData

/// A player's seasons, newest first: where they finished, their record and averages. Each row
/// opens that season's rank timeline and stats.
struct SeasonHistoryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var player: Player

    @State private var rows: [Row] = []

    struct Row: Identifiable {
        let season: Season
        let stats: SeasonStats
        let result: SeasonResult?
        var id: NSManagedObjectID { season.objectID }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if rows.isEmpty {
                    Text("No seasons yet.").foregroundColor(.secondary).padding(.top, 40)
                        .frame(maxWidth: .infinity)
                }
                ForEach(rows) { row in
                    NavigationLink(value: row.season.isActive
                                   ? DashboardRoute.rankTimeline(player: player)
                                   : DashboardRoute.seasonTimeline(player: player, season: row.season)) {
                        card(row)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("seasonRow-\(row.season.number)")
                }
            }
            .padding()
        }
        .background(Color("AppBackground").ignoresSafeArea())
        .navigationTitle("Season History")
        .onAppear(perform: load)
    }

    private func card(_ row: Row) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(row.season.name ?? "Season").font(.headline)
                if row.season.isActive {
                    Text("Current").font(.caption).bold()
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.green.opacity(0.15)).foregroundColor(.green)
                        .clipShape(Capsule())
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary)
            }
            Text(dates(row.season)).font(.caption).foregroundColor(.secondary)
            if let result = row.result {
                Text(result.position > 0
                     ? "Finished #\(result.position) of \(result.rankedPlayerCount) · \(result.finalRank ?? "") · \(result.finalRankPoints) RP"
                     : "Finished \(result.finalRank ?? "") · \(result.finalRankPoints) RP\(result.wasInPlacement ? " (in placement)" : "")")
                    .font(.subheadline)
            } else if row.season.isActive {
                Text("Now \(RankSystem.rankName(for: player.rankPoints)) · \(player.rankPoints) RP").font(.subheadline)
            }
            if row.stats.games > 0 {
                let avg = row.stats.averages
                Text("\(row.stats.wins)–\(row.stats.losses) · MVP ×\(row.stats.mvps) · \(SeasonStats.format(avg.points)) PTS, \(SeasonStats.format(avg.rebounds)) REB, \(SeasonStats.format(avg.assists)) AST per game")
                    .font(.caption).foregroundColor(.secondary)
            } else {
                Text("No ranked games").font(.caption).foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func load() {
        rows = SeasonHistory.seasons(for: player, in: viewContext).map {
            Row(season: $0, stats: SeasonHistory.stats(of: player, in: $0), result: SeasonHistory.result(of: player, in: $0))
        }
    }

    private func dates(_ season: Season) -> String {
        let start = season.startDate?.formatted(date: .abbreviated, time: .omitted) ?? "—"
        let end = season.endDate?.formatted(date: .abbreviated, time: .omitted) ?? "—"
        return season.isActive ? "Started \(start) · scheduled to end \(end)" : "\(start) – \(end)"
    }
}

/// Finished seasons, for everyone: each opens its final standings.
struct PastSeasonsView: View {
    @FetchRequest(
        sortDescriptors: [SortDescriptor(\Season.number, order: .reverse)],
        predicate: NSPredicate(format: "isActive == NO")
    ) private var seasons: FetchedResults<Season>

    var body: some View {
        List {
            if seasons.isEmpty {
                Text("No finished seasons yet.").foregroundColor(.secondary)
            }
            ForEach(seasons, id: \.objectID) { season in
                NavigationLink(value: DashboardRoute.seasonStandings(season: season)) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(season.name ?? "Season").font(.headline)
                        Text(PastSeasonsView.dates(season)).font(.caption).foregroundColor(.secondary)
                        if let champ = SeasonHistory.finalStandings(of: season).first(where: { $0.position == 1 }) {
                            Label("Champion: \(champ.player?.username ?? "?")", systemImage: "trophy.fill")
                                .font(.caption).foregroundColor(.orange)
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color("AppBackground").ignoresSafeArea())
        .navigationTitle("Past Seasons")
    }

    static func dates(_ season: Season) -> String {
        let start = season.startDate?.formatted(date: .abbreviated, time: .omitted) ?? "—"
        let end = season.endDate?.formatted(date: .abbreviated, time: .omitted) ?? "—"
        return "\(start) – \(end)"
    }
}

/// A finished season's final leaderboard, from the snapshot taken when it ended.
struct SeasonStandingsView: View {
    @ObservedObject var season: Season

    var body: some View {
        let standings = SeasonHistory.finalStandings(of: season)
        List {
            Section(header: Text(PastSeasonsView.dates(season))) {
                if standings.isEmpty {
                    Text("No final standings were saved for this season.").foregroundColor(.secondary)
                }
                ForEach(standings, id: \.objectID) { result in
                    let stats = result.player.map { SeasonHistory.stats(of: $0, in: season) } ?? .empty
                    HStack(spacing: 12) {
                        Text(result.position > 0 ? "#\(result.position)" : "–")
                            .font(.headline)
                            .foregroundColor(medal(result.position))
                            .frame(width: 40, alignment: .leading)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.player?.username ?? "Former member").font(.body)
                            Text("\(result.finalRank ?? "") · \(stats.wins)–\(stats.losses)\(result.wasInPlacement ? " · in placement" : "")")
                                .font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                        Text("\(result.finalRankPoints) RP").font(.subheadline).bold()
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("standing-\(result.player?.username ?? "")")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color("AppBackground").ignoresSafeArea())
        .navigationTitle("\(season.name ?? "Season") Final")
    }

    private func medal(_ position: Int64) -> Color {
        switch position {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .brown
        default: return .primary
        }
    }
}
