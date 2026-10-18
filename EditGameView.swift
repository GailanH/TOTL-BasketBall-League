import SwiftUI
import CoreData

/// Lets staff correct a mistakenly-logged game. Reverses the game's original RP impact, then
/// recomputes and applies a new one against the player's current rank — an approximation
/// (it doesn't rewind and replay full history), but keeps rankPoints accurate going forward.
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
                TextField("Points", text: $points).keyboardType(.numberPad)
                TextField("Rebounds", text: $rebounds).keyboardType(.numberPad)
                TextField("Assists", text: $assists).keyboardType(.numberPad)
                TextField("Blocks", text: $blocks).keyboardType(.numberPad)
                TextField("Steals", text: $steals).keyboardType(.numberPad)

                if let errorMessage {
                    Label(errorMessage, systemImage: "xmark.circle.fill")
                        .foregroundColor(.red)
                }

                Button("Save Changes") {
                    save()
                }
                .buttonStyle(.borderedProminent)
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
            }
        }
    }

    private func save() {
        guard let p = Int64(points), let r = Int64(rebounds), let a = Int64(assists),
              let b = Int64(blocks), let s = Int64(steals),
              p >= 0, r >= 0, a >= 0, b >= 0, s >= 0
        else {
            errorMessage = "Stats must be whole numbers, 0 or greater."
            return
        }

        let boundsError = GameStatBounds.validate(points: p, rebounds: r, assists: a, blocks: b, steals: s)
        if let boundsError {
            errorMessage = boundsError
            return
        }

        game.points = p
        game.rebounds = r
        game.assists = a
        game.blocks = b
        game.steals = s

        // Only Competitive members are ranked — a Casual member's game stats can still be
        // corrected, but it never carries an RP effect to undo or reapply.
        if AppConstants.isRanked(player.membership) {
            let oldRank = RankSystem.rankName(for: player.rankPoints)

            // Undo this game's old effect, then score the corrected stats against the player's
            // rank as it stands with that effect removed.
            let pointsWithoutThisGame = max(0, player.rankPoints - game.rpDelta)
            let rankWithoutThisGame = RankSystem.rankName(for: pointsWithoutThisGame)
            let newGain = RankSystem.rpGain(points: p, rebounds: r, assists: a, blocks: b, steals: s, at: rankWithoutThisGame)

            let newTotal = max(0, pointsWithoutThisGame + newGain)
            game.rpDelta = newTotal - pointsWithoutThisGame
            player.rankPoints = newTotal

            let newRank = RankSystem.rankName(for: player.rankPoints)
            if newRank != oldRank {
                let change = RankChange(context: viewContext)
                change.id = UUID()
                change.date = Date()
                change.newRank = newRank
                change.player = player
                player.lastRank = newRank
            }
        } else {
            game.rpDelta = 0
        }

        do {
            try viewContext.save()
            dismiss()
        } catch {
            viewContext.rollback()
            errorMessage = "Couldn't save: \(error.localizedDescription)"
        }
    }
}
