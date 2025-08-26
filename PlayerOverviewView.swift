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
            Text("🏅 Rank: \(rankFromPoints(player.rankPoints)) (\(player.rankPoints) RP)")

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

    func rankFromPoints(_ points: Int64) -> String {
        let ranks = [
            ("Rookie", 0, 100),
            ("Bronze III", 101, 150),
            ("Bronze II", 151, 200),
            ("Bronze I", 201, 250),
            ("Silver III", 251, 300),
            ("Silver II", 301, 350),
            ("Silver I", 351, 400),
            ("Gold III", 401, 450),
            ("Gold II", 451, 500),
            ("Gold I", 501, 550)
        ]

        for (name, min, max) in ranks {
            if Int(points) >= min && Int(points) <= max {
                return name
            }
        }
        return "Unranked"
    }
}
