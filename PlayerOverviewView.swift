import SwiftUI
import CoreData

struct PlayerOverviewView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var player: Player

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Player Overview")
                    .font(.title2).bold()

                Label(player.username ?? "Unknown", systemImage: "person.crop.circle.fill")
                Text("Role: \((player.role ?? "player").capitalized)")
                Text("Membership: \(player.membership ?? "None")")
                PlayerRankSummary(player: player)

                if let season = SeasonManager.activeSeason(in: viewContext) {
                    SeasonStatsCard(stats: SeasonHistory.stats(of: player, in: season),
                                    nightsAttended: SeasonHistory.nightsAttended(by: player, in: season))
                }
                NavigationLink(value: DashboardRoute.seasonHistory(player: player)) {
                    Label("Season History", systemImage: "clock.arrow.circlepath")
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("overviewSeasonHistory")

                Divider()

                let gameList = (player.games as? Set<Game>)?.sorted(by: {
                    ($0.date ?? .distantPast) > ($1.date ?? .distantPast)
                }) ?? []

                if gameList.isEmpty {
                    Text("No games found.")
                        .italic()
                } else {
                    let ranked = gameList.filter { $0.match != nil }
                    if !ranked.isEmpty {
                        let wins = ranked.filter(\.won).count
                        let mvps = ranked.filter { $0.award == Award.mvp.rawValue }.count
                        Text("All-time: \(wins)–\(ranked.count - wins) · MVP ×\(mvps)")
                            .font(.subheadline)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Last 5 Games")
                            .font(.headline)

                        ForEach(gameList.prefix(5), id: \.self) { game in
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(game.date?.formatted(date: .abbreviated, time: .omitted) ?? "Unknown")
                                    if game.match != nil {
                                        Text(game.won ? "W" : "L").bold().foregroundColor(game.won ? .green : .red)
                                    }
                                    if let award = game.award {
                                        Text(award).bold().foregroundColor(.orange)
                                    }
                                    if game.isPlacement {
                                        Text("Placement").font(.caption).foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Text("\(game.rpDelta >= 0 ? "+" : "")\(game.rpDelta) RP")
                                        .foregroundColor(game.rpDelta >= 0 ? .green : .red)
                                }
                                Text("PTS: \(game.points)  REB: \(game.rebounds)  AST: \(game.assists)")
                                Text("BLK: \(game.blocks)  STL: \(game.steals)")
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .cardStyle()
                        }
                    }
                }

                Spacer()
            }
            .padding()
        }
        .background(Color("AppBackground").ignoresSafeArea())
        .navigationTitle("")
    }
}

/// Rank, RP, and placement status for a player. Observes the player, so it updates as soon as
/// a game is recorded instead of waiting for the screen to reload.
struct PlayerRankSummary: View {
    @ObservedObject var player: Player

    var body: some View {
        if !AppConstants.isRanked(player.membership) {
            Label("Not Ranked — Competitive membership required", systemImage: "rosette")
                .foregroundColor(.gray)
        } else if player.placementGamesRemaining > 0 {
            VStack(spacing: 4) {
                Label("Placement: \(player.placementGamesRemaining) game\(player.placementGamesRemaining == 1 ? "" : "s") left", systemImage: "rosette")
                Text("Currently \(RankSystem.rankName(for: player.rankPoints)) (\(player.rankPoints) RP)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        } else {
            Label("Rank: \(RankSystem.rankName(for: player.rankPoints)) (\(player.rankPoints) RP)", systemImage: "rosette")
        }
    }
}
