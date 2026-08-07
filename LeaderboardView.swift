import SwiftUI
import CoreData

struct LeaderboardView: View {
    @FetchRequest(
        sortDescriptors: [SortDescriptor(\Player.rankPoints, order: .reverse)],
        predicate: NSPredicate(format: "role == %@", "player"),
        animation: .default
    ) private var players: FetchedResults<Player>

    var body: some View {
        VStack(spacing: 16) {
            Text("🏆 Leaderboard")
                .font(.title).bold()

            if players.isEmpty {
                Text("No players found.")
                    .foregroundColor(.gray)
            } else {
                List {
                    ForEach(Array(players.enumerated()), id: \.element) { index, player in
                        HStack(spacing: 12) {
                            // Profile Picture
                            if let data = player.profileImage, let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 40, height: 40)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1))
                            } else {
                                Image(systemName: "person.crop.circle.fill")
                                    .resizable()
                                    .frame(width: 40, height: 40)
                                    .foregroundColor(.gray)
                            }

                            // Player Info
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(index + 1). \(player.username ?? "Unknown")")
                                    .font(.headline)

                                Text("\(RankSystem.rankName(for: player.rankPoints)) — \(player.rankPoints) RP")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.plain)
            }
        }
        .padding()
        .navigationTitle("Leaderboard")
    }
}
