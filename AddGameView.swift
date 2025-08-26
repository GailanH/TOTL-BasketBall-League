import SwiftUI
import CoreData

struct PromotionAlert: Identifiable {
    let id = UUID()
    let message: String
}

struct AddGameView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss

    var employee: Player

    @FetchRequest(
        sortDescriptors: [SortDescriptor(\Player.username)],
        predicate: NSPredicate(format: "role == %@", "player"),
        animation: .default
    ) private var players: FetchedResults<Player>

    @State private var selectedPlayer: Player?
    @State private var points = ""
    @State private var rebounds = ""
    @State private var assists = ""
    @State private var blocks = ""
    @State private var steals = ""
    @State private var message = ""
    @State private var promotionMessage: PromotionAlert? = nil

    var body: some View {
        Form {
            Section(header: Text("Select Player")) {
                Picker("Player", selection: $selectedPlayer) {
                    ForEach(players, id: \.self) { player in
                        Text(player.username ?? "Unknown").tag(Optional(player))
                    }
                }
            }

            Section(header: Text("Enter Game Stats")) {
                TextField("Points", text: $points).keyboardType(.numberPad)
                TextField("Rebounds", text: $rebounds).keyboardType(.numberPad)
                TextField("Assists", text: $assists).keyboardType(.numberPad)
                TextField("Blocks", text: $blocks).keyboardType(.numberPad)
                TextField("Steals", text: $steals).keyboardType(.numberPad)
            }

            Section {
                Button("Submit Game") {
                    submitGame()
                }
                .buttonStyle(.borderedProminent)
            }

            if !message.isEmpty {
                Section {
                    Text(message)
                        .foregroundColor(.green)
                }
            }
        }
        .navigationTitle("Add Game")
        .alert(item: $promotionMessage) { alert in
            Alert(title: Text("Rank Change!"), message: Text(alert.message), dismissButton: .default(Text("OK")))
        }
    }

    private func submitGame() {
        guard let player = selectedPlayer,
              let p = Int64(points),
              let r = Int64(rebounds),
              let a = Int64(assists),
              let b = Int64(blocks),
              let s = Int64(steals)
        else {
            message = "Please fill out all fields and select a player."
            return
        }

        let game = Game(context: viewContext)
        game.points = p
        game.rebounds = r
        game.assists = a
        game.blocks = b
        game.steals = s
        game.date = Date()
        game.player = selectedPlayer
        
        do {
            try viewContext.save()
            print("Game saved successfully.")
        } catch {
            print("❌ Failed to save game: \(error.localizedDescription)")
        }


        let currentRank = rankFromPoints(player.rankPoints)
        let averages = rankAverages[currentRank] ?? [:]

        var individualGains: [Int64] = []

        individualGains.append(compareStat("points", value: p, avg: averages["points"] ?? 0))
        individualGains.append(compareStat("rebounds", value: r, avg: averages["rebounds"] ?? 0))
        individualGains.append(compareStat("assists", value: a, avg: averages["assists"] ?? 0))
        individualGains.append(compareStat("blocks", value: b, avg: averages["blocks"] ?? 0))
        individualGains.append(compareStat("steals", value: s, avg: averages["steals"] ?? 0))

        let rawTotal = individualGains.reduce(0, +)
        let gain = max(min(rawTotal, 50), -20)  // Cap total between -20 and +50


        let oldPoints = player.rankPoints
        player.rankPoints = max(0, player.rankPoints + gain)

        let newRank = rankFromPoints(player.rankPoints)

        if newRank != currentRank {
            let change = RankChange(context: viewContext)
                change.id = UUID()
                change.date = Date()
                change.newRank = newRank
                change.player = player
            
            let rankMessage = player.rankPoints > oldPoints ? "🎉 Promoted to \(newRank)!" : "⬇️ Demoted to \(newRank)."
            promotionMessage = PromotionAlert(message: rankMessage)
        }

        do {
            try viewContext.save()
            message = "✅ Game recorded. \(gain >= 0 ? "+" : "")\(gain) RP."
            clearFields()
        } catch {
            message = "❌ Failed to save game: \(error.localizedDescription)"
        }
    }

    private func compareStat(_ name: String, value: Int64, avg: Int64) -> Int64 {
        let difference = value - avg
        if difference > 0 {
            return min(difference * 2, 50)  // Cap max gain
        } else if difference < 0 {
            return max(difference * 1, -20) // Cap max loss
        } else {
            return 0
        }
    }


    private func clearFields() {
        points = ""
        rebounds = ""
        assists = ""
        blocks = ""
        steals = ""
    }

    private func rankFromPoints(_ points: Int64) -> String {
        let ranks = [
            ("Rookie", 0, 100),
            ("Bronze III", 100, 150),
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

    private let rankAverages: [String: [String: Int64]] = [
        "Rookie":     ["points": 5,  "rebounds": 3, "assists": 2, "blocks": 0, "steals": 1],
        "Bronze III": ["points": 7,  "rebounds": 4, "assists": 2, "blocks": 0, "steals": 1],
        "Bronze II":  ["points": 9,  "rebounds": 4, "assists": 3, "blocks": 0, "steals": 2],
        "Bronze I":   ["points": 11, "rebounds": 5, "assists": 3, "blocks": 1, "steals": 2],
        "Silver III": ["points": 10, "rebounds": 4, "assists": 3, "blocks": 1, "steals": 2],
        "Silver II":  ["points": 11, "rebounds": 5, "assists": 3, "blocks": 1, "steals": 2],
        "Silver I":   ["points": 12, "rebounds": 6, "assists": 3, "blocks": 1, "steals": 3],
        "Gold III":   ["points": 10, "rebounds": 5, "assists": 6, "blocks": 1, "steals": 2],
        "Gold II":    ["points": 9,  "rebounds": 5, "assists": 3, "blocks": 1, "steals": 2],
        "Gold I":     ["points": 13, "rebounds": 7, "assists": 2, "blocks": 0, "steals": 3]
    ]
}
