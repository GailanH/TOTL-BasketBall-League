import SwiftUI
import CoreData

struct EditAccountsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    var currentEmployee: Player

    @FetchRequest(
        sortDescriptors: [SortDescriptor(\Player.username)],
        predicate: NSPredicate(format: "role != %@", "employee"),
        animation: .default
    ) private var allPlayers: FetchedResults<Player>

    @State private var searchText: String = ""
    @State private var selectedPlayer: Player?

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
            Text("Edit Player Accounts")
                .font(.title2).bold()

            TextField("Search by username...", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)

            List(filteredPlayers, id: \.self) { player in
                Button {
                    selectedPlayer = player
                } label: {
                    VStack(alignment: .leading) {
                        Text(player.username ?? "Unknown")
                            .font(.headline)
                        Text("Membership: \(player.membership ?? "None")")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
            }

            .sheet(item: $selectedPlayer) { player in
                EditPlayerDetailView(player: player)
            }

            Spacer()
        }
        .padding(.top)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Back") {
                    dismiss()
                    }
                }
            }
        }
    }
