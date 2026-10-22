import SwiftUI
import CoreData

struct EditAccountsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    var currentEmployee: Player
    var filterPendingOnly: Bool = false

    @FetchRequest private var allPlayers: FetchedResults<Player>

    @State private var searchText: String = ""
    @State private var selectedPlayer: Player?

    init(currentEmployee: Player, filterPendingOnly: Bool = false) {
        self.currentEmployee = currentEmployee
        self.filterPendingOnly = filterPendingOnly

        let predicate = filterPendingOnly
            ? NSPredicate(format: "role == %@", AppConstants.employeePendingRole)
            : NSPredicate(format: "NOT (role IN %@)", AppConstants.staffRoles)

        _allPlayers = FetchRequest(
            sortDescriptors: [SortDescriptor(\Player.username)],
            predicate: predicate,
            animation: .default
        )
    }

    var filteredPlayers: [Player] {
        if searchText.isEmpty {
            return Array(allPlayers)
        } else {
            return allPlayers.filter {
                $0.username?.lowercased().contains(searchText.lowercased()) ?? false
            }
        }
    }

    var body: some View {
        VStack {
            Text(filterPendingOnly ? "Pending Approvals" : "Edit Player Accounts")
                .font(.title2).bold()

            TextField("Search by username...", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)

            #if DEBUG // DebugTools: sample league for testing. Not in release builds.
            if !filterPendingOnly { SampleLeagueButton() }
            #endif

            List(filteredPlayers, id: \.self) { player in
                Button {
                    selectedPlayer = player
                } label: {
                    VStack(alignment: .leading) {
                        HStack {
                            Text(player.username ?? "Unknown")
                                .font(.headline)
                            if player.role == AppConstants.employeePendingRole {
                                Text("Pending Approval")
                                    .font(.caption).bold()
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.orange.opacity(0.2))
                                    .foregroundColor(.orange)
                                    .clipShape(Capsule())
                            }
                        }
                        Text("Membership: \(player.membership ?? "None")")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .sheet(item: $selectedPlayer) { player in
                EditPlayerDetailView(player: player)
            }

            Spacer()
        }
        .padding(.top)
        .background(Color("AppBackground").ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Back") {
                    dismiss()
                    }
                }
            }
        }
    }
