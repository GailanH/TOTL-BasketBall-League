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
                        Text("Rank Points: \(player.rankPoints)")

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

                        if player.role == "employee" {
                            NavigationLink(value: DashboardRoute.addGame) {
                                Text("Add Game")
                            }
                            .buttonStyle(.borderedProminent)

                            NavigationLink(value: DashboardRoute.editAccounts) {
                                Text("Edit Player Accounts")
                            }
                            .buttonStyle(.bordered)
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
                        LeaderboardView()
                    case .editAccounts:
                        if let player = player {
                            EditAccountsView(currentEmployee: player)
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

                let currentRank = rankFromPoints(casted.rankPoints)
                if casted.lastRank != currentRank {
                    if let oldRank = casted.lastRank {
                        if rankIndex(currentRank) > rankIndex(oldRank) {
                            rankAlert = RankChangeMessage(text: "🎉 Promoted to \(currentRank)!")
                        } else {
                            rankAlert = RankChangeMessage(text: "⬇️ Demoted to \(currentRank).")
                        }
                    } else {
                        rankAlert = RankChangeMessage(text: "Current Rank: \(currentRank)")
                    }

                    casted.lastRank = currentRank
                    try? viewContext.save()
                }
            }
        } catch {
            print("❌ Failed to fetch player in DashboardView: \(error)")
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

    func rankIndex(_ rank: String) -> Int {
        let allRanks = [
            "Rookie", "Bronze III", "Bronze II", "Bronze I",
            "Silver III", "Silver II", "Silver I",
            "Gold III", "Gold II", "Gold I"
        ]
        return allRanks.firstIndex(of: rank) ?? -1
    }
}

struct RankChangeMessage: Identifiable {
    let id = UUID()
    let text: String
}
