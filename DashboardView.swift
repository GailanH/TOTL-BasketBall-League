import SwiftUI
import CoreData

struct DashboardView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss

    let playerID: NSManagedObjectID
    @Binding var loggedInPlayer: Player?

    @State private var player: Player?
    @State private var rankAlert: RankChangeMessage? = nil
    @State private var selectedRoute: DashboardRoute? = nil
    @State private var didLoadPlayer = false

    @FetchRequest(
        sortDescriptors: [],
        predicate: NSPredicate(format: "role == %@", AppConstants.employeePendingRole)
    ) private var pendingEmployees: FetchedResults<Player>

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if let player = player {
                        Text("Welcome, \(player.username ?? "User")!")
                            .font(.title).bold()

                        Divider()

                        Text("Role: \((player.role ?? "player").capitalized)")
                        Text("Membership: \(player.membership ?? "None")")
                        PlayerRankSummary(player: player)

                        if player.role == AppConstants.employeePendingRole {
                            Label("Your employee account is pending approval from an existing staff member.", systemImage: "clock.fill")
                                .font(.footnote)
                                .foregroundColor(.orange)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }

                        UpcomingGameNightsSection(viewer: NightViewer(player))
                            .padding(.top, 8)

                        Divider().padding(.vertical)

                        NavigationLink(value: DashboardRoute.playerOverview) {
                            Text("Player Overview")
                        }
                        .buttonStyle(.bordered)

                        NavigationLink(value: DashboardRoute.leaderboard) {
                            Text("Leaderboard")
                        }
                        .buttonStyle(.bordered)

                        NavigationLink(value: DashboardRoute.coaching) {
                            Text("Coaching Sessions")
                        }
                        .buttonStyle(.bordered)

                        NavigationLink(value: DashboardRoute.editProfile(playerID: player.objectID)) {
                            Text("Edit Profile")
                        }
                        .buttonStyle(.bordered)

                        NavigationLink(value: DashboardRoute.rankTimeline(player: player)) {
                            Text("Rank Timeline")
                        }
                        .buttonStyle(.bordered)

                        if AppConstants.isStaff(player.role) {
                            NavigationLink(value: DashboardRoute.addGame) {
                                Text("Record Game")
                            }
                            .buttonStyle(.borderedProminent)

                            NavigationLink(value: DashboardRoute.manageGameNights) {
                                Text("Game Nights")
                            }
                            .buttonStyle(.bordered)

                            NavigationLink(value: DashboardRoute.seasons) {
                                Text("Seasons")
                            }
                            .buttonStyle(.bordered)

                            NavigationLink(value: DashboardRoute.editAccounts) {
                                Text("Edit Player Accounts")
                            }
                            .buttonStyle(.bordered)

                            if !pendingEmployees.isEmpty {
                                NavigationLink(value: DashboardRoute.pendingApprovals) {
                                    Label("Pending Approvals (\(pendingEmployees.count))", systemImage: "clock.fill")
                                }
                                .buttonStyle(.bordered)
                                .tint(.orange)
                            }
                        }

                        Spacer()

                        Button("Logout") {
                            loggedInPlayer = nil
                        }
                        .foregroundColor(.red)
                    } else {
                        ProgressView("Loading player...")
                    }
                }
                .padding()
                .navigationTitle("Dashboard")
                .navigationDestination(for: DashboardRoute.self) { route in
                    switch route {
                    case .coaching:
                        if let player = player {
                            CoachingListView(player: player)
                        }
                    case .leaderboard:
                        LeaderboardView(viewer: player)
                    case .seasons:
                        SeasonsView()
                    case .upcomingGameNights:
                        UpcomingGameNightsView(viewer: NightViewer(player))
                    case .gameNight(let id):
                        GameNightDetailView(nightID: id, viewer: NightViewer(player))
                    case .roster(let nightID):
                        RosterView(nightID: nightID, staffUsername: player?.username)
                    case .recordGame(let prefill):
                        if let player = player {
                            AddGameView(employee: player, prefill: prefill)
                        }
                    case .manageGameNights:
                        ManageGameNightsView(staffUsername: player?.username)
                    case .venues:
                        VenuesView()
                    case .editAccounts:
                        if let player = player {
                            EditAccountsView(currentEmployee: player)
                        }
                    case .pendingApprovals:
                        if let player = player {
                            EditAccountsView(currentEmployee: player, filterPendingOnly: true)
                        }
                    case .overview, .playerOverview:
                        if let player = player {
                            PlayerOverviewView(player: player)
                        }
                    case .addGame:
                        if let player = player {
                            AddGameView(employee: player)
                        }
                    case .editProfile(let playerID):
                        EditProfileView(playerID: playerID)
                    case .rankTimeline(let player):
                        RankHistoryTimelineView(player: player)
                    }
                }
                .alert(item: $rankAlert) { alert in
                    Alert(title: Text("Rank Update"), message: Text(alert.text), dismissButton: .default(Text("OK")))
                }
            }
            .background(Color("AppBackground").ignoresSafeArea())
            .task {
                await MainActor.run {
                    loadPlayerSafely()
                }
            }
        }
    }

    private func loadPlayerSafely() {
        guard !didLoadPlayer else { return }
        didLoadPlayer = true

        do {
            let object = try viewContext.existingObject(with: playerID)
            if let casted = object as? Player {
                self.player = casted

                let currentRank = RankSystem.rankName(for: casted.rankPoints)
                if AppConstants.isRanked(casted.membership), casted.lastRank != currentRank {
                    if let oldRank = casted.lastRank {
                        if (RankSystem.index(of: currentRank) ?? -1) > (RankSystem.index(of: oldRank) ?? -1) {
                            rankAlert = RankChangeMessage(text: "Promoted to \(currentRank)!")
                        } else {
                            rankAlert = RankChangeMessage(text: "Demoted to \(currentRank).")
                        }
                    } else {
                        rankAlert = RankChangeMessage(text: "Current Rank: \(currentRank)")
                    }

                    casted.lastRank = currentRank
                    try? viewContext.save()
                }
            }
        } catch {
            #if DEBUG
            print("❌ Failed to fetch player in DashboardView: \(error)")
            #endif
        }
    }

}

struct RankChangeMessage: Identifiable {
    let id = UUID()
    let text: String
}
