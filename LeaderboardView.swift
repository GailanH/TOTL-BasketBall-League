import SwiftUI
import CoreData

struct LeaderboardView: View {
    @FetchRequest(
        sortDescriptors: [SortDescriptor(\Player.rankPoints, order: .reverse)],
        predicate: NSPredicate(format: "membership == %@ AND placementGamesRemaining <= 0", AppConstants.competitiveMembership),
        animation: .default
    ) private var players: FetchedResults<Player>

    /// Competitive players still playing placement games this season. They appear once placed.
    @FetchRequest(
        sortDescriptors: [],
        predicate: NSPredicate(format: "membership == %@ AND placementGamesRemaining > 0", AppConstants.competitiveMembership)
    ) private var inPlacement: FetchedResults<Player>

    @FetchRequest(
        sortDescriptors: [SortDescriptor(\Season.number, order: .reverse)],
        predicate: NSPredicate(format: "isActive == YES")
    ) private var activeSeasons: FetchedResults<Season>

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Label("Leaderboard", systemImage: "trophy.fill")
                    .font(.title).bold()
                    .padding(.top)

                if let season = activeSeasons.first {
                    Text(season.name ?? "Current Season")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                if !inPlacement.isEmpty {
                    Text("\(inPlacement.count) player\(inPlacement.count == 1 ? "" : "s") still in placement games")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if players.isEmpty {
                    Text("No placed Competitive players yet. Players appear here after their \(CompetitiveRules.placementGames) placement games.")
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                } else {
                    VStack(spacing: 12) {
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
                                    HStack(spacing: 6) {
                                        Text("\(index + 1). \(player.username ?? "Unknown")")
                                            .font(.headline)

                                        if let staffLabel = staffLabel(for: player) {
                                            Text(staffLabel)
                                                .font(.caption).bold()
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.blue.opacity(0.15))
                                                .foregroundColor(.blue)
                                                .clipShape(Capsule())
                                        }
                                    }

                                    Text("\(RankSystem.rankName(for: player.rankPoints)) — \(player.rankPoints) RP")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()
                            }
                            .padding()
                            .cardStyle()
                        }
                    }
                    .padding(.horizontal)
                }

                Spacer(minLength: 20)
            }
        }
        .background(Color("AppBackground").ignoresSafeArea())
        .navigationTitle("Leaderboard")
    }

    private func staffLabel(for player: Player) -> String? {
        switch player.role {
        case AppConstants.employeeRole: return "Employee"
        case AppConstants.administratorRole: return "Administrator"
        default: return nil
        }
    }
}
