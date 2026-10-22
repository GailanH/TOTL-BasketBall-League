import SwiftUI
import CoreData

struct LeaderboardView: View {
    /// The logged-in player. Placed players see a "Your Standing" card (a celebration in the
    /// top 3) that collapses into a pinned bar once it scrolls off screen.
    var viewer: Player? = nil

    @State private var standingCardVisible = true

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
        ScrollViewReader { proxy in
        ScrollView {
            VStack(spacing: 16) {
                if let season = activeSeasons.first {
                    Text(season.name ?? "Current Season")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                standingHeader
                    .padding(.horizontal)
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(key: StandingCardBottomKey.self,
                                                   value: geo.frame(in: .named("leaderboard")).maxY)
                        }
                    )

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
                                        if let medal = Podium.color(for: index + 1) {
                                            Image(systemName: "medal.fill")
                                                .foregroundStyle(medal)
                                                .accessibilityLabel("\(Podium.ordinal(index + 1)) place")
                                        }
                                        Text("\(index + 1). \(player.username ?? "Unknown")")
                                            .font(.headline)
                                        if player.objectID == viewer?.objectID {
                                            Text("You")
                                                .font(.caption).bold()
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.accentColor.opacity(0.15))
                                                .clipShape(Capsule())
                                        }

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
                            .id(player.objectID)
                            .overlay {
                                if let medal = Podium.color(for: index + 1) {
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(medal.opacity(0.8), lineWidth: 2)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                Spacer(minLength: 20)
            }
        }
        .coordinateSpace(name: "leaderboard")
        .onPreferenceChange(StandingCardBottomKey.self) { bottom in
            // Hysteresis: collapse once the card is fully off screen, expand again only when
            // a good part of it is back, so the bar can't flicker at the boundary.
            let visible = standingCardVisible ? bottom > 0 : bottom > 80
            if visible != standingCardVisible {
                withAnimation(.easeInOut(duration: 0.2)) { standingCardVisible = visible }
            }
        }
        // An overlay, not a safe-area inset: the bar floats over the list without moving it,
        // so showing the bar can't push the card back into view.
        .overlay(alignment: .top) {
            if !standingCardVisible, let standing, let viewer {
                CompactStandingBar(standing: standing) {
                    withAnimation { proxy.scrollTo(viewer.objectID, anchor: .center) }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        }
        .background(Color("AppBackground").ignoresSafeArea())
        .navigationTitle("Leaderboard")
    }

    /// Celebration for the top 3, a standing card for everyone else who's placed, and a
    /// placement note for Competitive players who aren't placed yet.
    @ViewBuilder
    private var standingHeader: some View {
        let seasonName = activeSeasons.first?.name ?? "this season"
        if let standing {
            if standing.place <= 3 {
                PodiumCelebrationBanner(standing: standing, seasonName: seasonName)
            } else {
                StandingCard(standing: standing, seasonName: seasonName)
            }
        } else if let viewer, AppConstants.isRanked(viewer.membership), viewer.placementGamesRemaining > 0 {
            VStack(spacing: 6) {
                Text("You're in placement")
                    .font(.headline)
                Text("\(viewer.placementGamesRemaining) placement game\(viewer.placementGamesRemaining == 1 ? "" : "s") left. You'll appear on the leaderboard once you're placed.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 20).fill(Color.accentColor.opacity(0.08)))
        }
    }

    /// The viewer's standing, if they're on the leaderboard.
    private var standing: LeaderboardStanding? {
        guard let viewer, let index = players.firstIndex(where: { $0.objectID == viewer.objectID }) else { return nil }
        let ranking = players.map { (username: $0.username ?? "Unknown", rankPoints: $0.rankPoints) }
        return LeaderboardStanding(ranking: ranking, index: index)
    }

    private func staffLabel(for player: Player) -> String? {
        switch player.role {
        case AppConstants.employeeRole: return "Employee"
        case AppConstants.administratorRole: return "Administrator"
        default: return nil
        }
    }
}

/// The bottom edge of the standing card in the leaderboard's scroll space. When it goes above
/// 0, the card has scrolled off and the compact bar takes over.
private struct StandingCardBottomKey: PreferenceKey {
    static var defaultValue: CGFloat = .infinity
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}
