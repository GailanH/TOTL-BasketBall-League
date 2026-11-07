import SwiftUI
import CoreData

/// The signed-in app: a tab bar with Home, Nights, Ranks and Profile, plus Staff for staff
/// accounts. Each tab has its own navigation stack; every screen reachable by a
/// `DashboardRoute` is registered once, in `AppDestinations`.
struct DashboardView: View {
    @Environment(\.managedObjectContext) private var viewContext

    let playerID: NSManagedObjectID
    @Binding var loggedInPlayer: Player?

    @State private var player: Player?
    @State private var rankAlert: RankChangeMessage? = nil
    @State private var didLoadPlayer = false
    @State private var selectedTab: AppTab = .home

    @FetchRequest(
        sortDescriptors: [],
        predicate: NSPredicate(format: "role == %@", AppConstants.employeePendingRole)
    ) private var pendingEmployees: FetchedResults<Player>

    enum AppTab: Hashable { case home, nights, ranks, profile, staff }

    var body: some View {
        Group {
            if let player {
                TabView(selection: $selectedTab) {
                    NavigationStack {
                        HomeView(player: player)
                            .modifier(AppDestinations(player: player))
                    }
                    .tabItem { Label("Home", systemImage: "house.fill") }
                    .tag(AppTab.home)

                    NavigationStack {
                        UpcomingGameNightsView(viewer: NightViewer(player))
                            .modifier(AppDestinations(player: player))
                    }
                    .tabItem { Label("Nights", systemImage: "calendar") }
                    .tag(AppTab.nights)

                    NavigationStack {
                        LeaderboardView(viewer: player)
                            .toolbar {
                                ToolbarItem(placement: .navigationBarTrailing) {
                                    NavigationLink(value: DashboardRoute.rankTimeline(player: player)) {
                                        Label("My Timeline", systemImage: "chart.line.uptrend.xyaxis")
                                    }
                                    .accessibilityIdentifier("myTimeline")
                                }
                            }
                            .modifier(AppDestinations(player: player))
                    }
                    .tabItem { Label("Ranks", systemImage: "trophy.fill") }
                    .tag(AppTab.ranks)

                    NavigationStack {
                        ProfileView(player: player) { loggedInPlayer = nil }
                            .modifier(AppDestinations(player: player))
                    }
                    .tabItem { Label("Profile", systemImage: "person.crop.circle") }
                    .tag(AppTab.profile)

                    if AppConstants.isStaff(player.role) {
                        NavigationStack {
                            StaffHubView(pendingCount: pendingEmployees.count)
                                .modifier(AppDestinations(player: player))
                        }
                        .tabItem { Label("Staff", systemImage: "list.bullet.clipboard") }
                        .badge(pendingEmployees.count)
                        .tag(AppTab.staff)
                    }
                }
                .tint(.orange)
            } else {
                ProgressView("Loading player...")
            }
        }
        .alert(item: $rankAlert) { alert in
            Alert(title: Text("Rank Update"), message: Text(alert.text), dismissButton: .default(Text("OK")))
        }
        .task {
            await MainActor.run { loadPlayerSafely() }
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

// MARK: Home tab

/// Home: who you are, where you stand, and your next game nights.
struct HomeView: View {
    @ObservedObject var player: Player

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text("Welcome, \(player.username ?? "User")!")
                        .font(.title).bold()
                    Text("\((player.membership ?? "No") ) member · \((player.role ?? "player").capitalized)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

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

                NavigationLink(value: DashboardRoute.coaching) {
                    Label("Coaching Sessions", systemImage: "figure.basketball")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
        .background(Color("AppBackground").ignoresSafeArea())
        .navigationTitle("Home")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: Profile tab

/// Profile: your stats and history, account settings, and log out.
struct ProfileView: View {
    @ObservedObject var player: Player
    let onLogout: () -> Void

    @State private var confirmLogout = false

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(player.username ?? "User").font(.title2).bold()
                    Text("\(player.membership ?? "No") member · \((player.role ?? "player").capitalized)")
                        .font(.subheadline).foregroundColor(.secondary)
                    if AppConstants.isRanked(player.membership) {
                        Text(player.placementGamesRemaining > 0
                             ? "Placement: \(player.placementGamesRemaining) games left"
                             : "\(RankSystem.rankName(for: player.rankPoints)) · \(player.rankPoints) RP")
                            .font(.subheadline)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("My Game") {
                NavigationLink(value: DashboardRoute.playerOverview) {
                    Label("Player Overview", systemImage: "person.text.rectangle")
                }
                NavigationLink(value: DashboardRoute.rankTimeline(player: player)) {
                    Label("Rank Timeline", systemImage: "chart.line.uptrend.xyaxis")
                }
                NavigationLink(value: DashboardRoute.seasonHistory(player: player)) {
                    Label("Season History", systemImage: "clock.arrow.circlepath")
                }
                NavigationLink(value: DashboardRoute.coaching) {
                    Label("Coaching Sessions", systemImage: "figure.basketball")
                }
            }

            Section("Account") {
                NavigationLink(value: DashboardRoute.editProfile(playerID: player.objectID)) {
                    Label("Edit Profile", systemImage: "pencil")
                }
                Button(role: .destructive) {
                    confirmLogout = true
                } label: {
                    Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                }
                .accessibilityIdentifier("logout")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color("AppBackground").ignoresSafeArea())
        .navigationTitle("Profile")
        .confirmationDialog("Log out?", isPresented: $confirmLogout, titleVisibility: .visible) {
            Button("Log Out", role: .destructive, action: onLogout)
            Button("Cancel", role: .cancel) {}
        }
    }
}

// MARK: Staff tab

/// Staff tools in one place. Only staff accounts see this tab.
struct StaffHubView: View {
    let pendingCount: Int

    var body: some View {
        List {
            Section("Game Day") {
                NavigationLink(value: DashboardRoute.addGame) {
                    Label("Record Game", systemImage: "square.and.pencil")
                }
                NavigationLink(value: DashboardRoute.manageGameNights) {
                    Label("Game Nights", systemImage: "calendar.badge.clock")
                }
                NavigationLink(value: DashboardRoute.venues) {
                    Label("Venues", systemImage: "mappin.and.ellipse")
                }
            }
            Section("League") {
                NavigationLink(value: DashboardRoute.seasons) {
                    Label("Seasons", systemImage: "flag.checkered")
                }
                NavigationLink(value: DashboardRoute.editAccounts) {
                    Label("Edit Player Accounts", systemImage: "person.2")
                }
                if pendingCount > 0 {
                    NavigationLink(value: DashboardRoute.pendingApprovals) {
                        Label("Pending Approvals (\(pendingCount))", systemImage: "clock.fill")
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color("AppBackground").ignoresSafeArea())
        .navigationTitle("Staff")
    }
}

// MARK: Destinations

/// Every screen a `DashboardRoute` can open, registered on each tab's navigation stack.
struct AppDestinations: ViewModifier {
    let player: Player

    func body(content: Content) -> some View {
        content.navigationDestination(for: DashboardRoute.self) { route in
            destination(for: route)
        }
    }

    @ViewBuilder
    private func destination(for route: DashboardRoute) -> some View {
        switch route {
        case .coaching:
            CoachingListView(player: player)
        case .leaderboard:
            LeaderboardView(viewer: player)
        case .seasons:
            SeasonsView()
        case .upcomingGameNights:
            UpcomingGameNightsView(viewer: NightViewer(player))
        case .gameNight(let id):
            GameNightDetailView(nightID: id, viewer: NightViewer(player))
        case .roster(let nightID):
            RosterView(nightID: nightID, staffUsername: player.username)
        case .recordGame(let prefill):
            AddGameView(employee: player, prefill: prefill)
        case .manageGameNights:
            ManageGameNightsView(staffUsername: player.username)
        case .venues:
            VenuesView()
        case .editAccounts:
            EditAccountsView(currentEmployee: player)
        case .pendingApprovals:
            EditAccountsView(currentEmployee: player, filterPendingOnly: true)
        case .overview, .playerOverview:
            PlayerOverviewView(player: player)
        case .addGame:
            AddGameView(employee: player)
        case .editProfile(let playerID):
            EditProfileView(playerID: playerID)
        case .rankTimeline(let player):
            RankHistoryTimelineView(player: player)
        case .seasonTimeline(let player, let season):
            RankHistoryTimelineView(player: player, season: season)
        case .seasonHistory(let player):
            SeasonHistoryView(player: player)
        case .pastSeasons:
            PastSeasonsView()
        case .seasonStandings(let season):
            SeasonStandingsView(season: season)
        }
    }
}

struct RankChangeMessage: Identifiable {
    let id = UUID()
    let text: String
}
