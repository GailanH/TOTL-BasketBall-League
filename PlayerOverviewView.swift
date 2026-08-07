import SwiftUI
import CoreData

struct PlayerOverviewView: View {
    @Environment(\.managedObjectContext) private var viewContext
    var player: Player

    var body: some View {
        VStack(spacing: 20) {
            Text("Player Overview")
                .font(.title2).bold()

            Text("👤 \(player.username ?? "Unknown")")
            Text("Role: \((player.role ?? "player").capitalized)")
            Text("Membership: \(player.membership ?? "None")")
            Text("🏅 Rank: \(RankSystem.rankName(for: player.rankPoints)) (\(player.rankPoints) RP)")

            Divider()

            let gameList = (player.games as? Set<Game>)?.sorted(by: {
                ($0.date ?? .distantPast) > ($1.date ?? .distantPast)
            }) ?? []

            if gameList.isEmpty {
                Text("No games found.")
                    .italic()
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Last 5 Games")
                        .font(.headline)

                    ForEach(gameList.prefix(5), id: \.self) { game in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Date: \(game.date?.formatted(date: .abbreviated, time: .omitted) ?? "Unknown")")
                            Text("PTS: \(game.points)  REB: \(game.rebounds)  AST: \(game.assists)")
                            Text("BLK: \(game.blocks)  STL: \(game.steals)")
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                }
            }

            Spacer()
        }
        .padding()
        .navigationTitle("")
        .onAppear {
            if let games = player.games as? Set<Game> {
                print("DEBUG: Loaded \(games.count) games for \(player.username ?? "unknown")")
                for game in games {
                    print("  - Game date: \(game.date?.formatted() ?? "nil") | PTS: \(game.points) | REB: \(game.rebounds)")
                }
            } else {
                print("DEBUG: No games found or not linked correctly")
            }
        }
    }
}
