import SwiftUI
import CoreData

/// Lets staff correct a mistakenly-logged stat line. The whole game is re-scored through
/// `MatchRecorder`, since fixing one player's stats can move MVP/SVP and everyone's RP.
struct EditGameView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss

    @ObservedObject var game: Game
    @ObservedObject var player: Player

    @State private var points = ""
    @State private var rebounds = ""
    @State private var assists = ""
    @State private var blocks = ""
    @State private var steals = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                if let match = game.match {
                    Section {
                        Text("\(Team(rawValue: game.team ?? "")?.displayName ?? "Team ?") · \(game.won ? "Won" : "Lost")\(game.award.map { " · \($0)" } ?? "")")
                        Text("Saving re-scores all \(MatchRecorder.games(in: match).count) players in this game.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Section(header: Text("Stats")) {
                    TextField("Points", text: $points).keyboardType(.numberPad)
                    TextField("Rebounds", text: $rebounds).keyboardType(.numberPad)
                    TextField("Assists", text: $assists).keyboardType(.numberPad)
                    TextField("Blocks", text: $blocks).keyboardType(.numberPad)
                    TextField("Steals", text: $steals).keyboardType(.numberPad)
                }

                if let errorMessage {
                    Label(errorMessage, systemImage: "xmark.circle.fill")
                        .foregroundColor(.red)
                }

                Button("Save Changes") { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!MatchRecorder.isEditable(game, in: viewContext))
            }
            .scrollContentBackground(.hidden)
            .background(Color("AppBackground").ignoresSafeArea())
            .navigationTitle("Edit Game")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                points = String(game.points)
                rebounds = String(game.rebounds)
                assists = String(game.assists)
                blocks = String(game.blocks)
                steals = String(game.steals)
                if !MatchRecorder.isEditable(game, in: viewContext) {
                    errorMessage = MatchRecorder.RecordError.pastSeason.localizedDescription
                }
            }
        }
    }

    private func save() {
        guard let p = Int64(points), let r = Int64(rebounds), let a = Int64(assists),
              let b = Int64(blocks), let s = Int64(steals) else {
            errorMessage = "Stats must be whole numbers, 0 or greater."
            return
        }

        do {
            try MatchRecorder.updateStats(of: game, to: StatLine(points: p, rebounds: r, assists: a, blocks: b, steals: s), in: viewContext)
            try viewContext.save()
            dismiss()
        } catch {
            viewContext.rollback()
            errorMessage = error.localizedDescription
        }
    }
}
