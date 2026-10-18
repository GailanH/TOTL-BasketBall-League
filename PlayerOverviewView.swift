import SwiftUI
import CoreData

struct PlayerOverviewView: View {
    @Environment(\.managedObjectContext) private var viewContext
    var player: Player

    var body: some View {
        VStack(spacing: 20) {
            Text("Player Overview")
                .font(.title2).bold()

            Label(player.username ?? "Unknown", systemImage: "person.crop.circle.fill")
            Text("Role: \((player.role ?? "player").capitalized)")
            Text("Membership: \(player.membership ?? "None")")
            if AppConstants.isRanked(player.membership) {
                Label("Rank: \(RankSystem.rankName(for: player.rankPoints)) (\(player.rankPoints) RP)", systemImage: "rosette")
            } else {
                Label("Not Ranked — Competitive membership required", systemImage: "rosette")
                    .foregroundColor(.gray)
            }

            Divider()

            let gameList = (player.games as? Set<Game>)?.sorted(by: {
                ($0.date ?? .distantPast) > ($1.date ?? .distantPast)
            }) ?? []

            if gameList.isEmpty {
                Text("No games found.")
                    .italic()
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Last 5 Games")
                        .font(.headline)

                    ForEach(gameList.prefix(5), id: \.self) { game in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Date: \(game.date?.formatted(date: .abbreviated, time: .omitted) ?? "Unknown")")
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
        .background(Color("AppBackground").ignoresSafeArea())
        .navigationTitle("")
    }
}
