import SwiftUI
import CoreData
import UniformTypeIdentifiers

struct PromotionAlert: Identifiable {
    let id = UUID()
    let message: String
}

struct CSVImportAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

struct AddGameView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss

    var employee: Player

    // This app's game history is Competitive-only — Casual members never get a game
    // recorded, so they're not offered here at all.
    @FetchRequest(
        sortDescriptors: [SortDescriptor(\Player.username)],
        predicate: NSPredicate(format: "membership == %@", AppConstants.competitiveMembership),
        animation: .default
    ) private var players: FetchedResults<Player>

    @State private var selectedPlayer: Player?
    @State private var points = ""
    @State private var rebounds = ""
    @State private var assists = ""
    @State private var blocks = ""
    @State private var steals = ""
    @State private var message = ""
    @State private var messageIsError = false
    @State private var promotionMessage: PromotionAlert? = nil

    @State private var showFileImporter = false
    @State private var csvSummary: String = ""
    @State private var csvAlert: CSVImportAlert? = nil

    /// Same fields the manual form collects — a row missing any of these columns is rejected.
    private static let requiredCSVColumns = ["username", "points", "rebounds", "assists", "blocks", "steals"]

    var body: some View {
        Form {
            Section(header: Text("Select Player")) {
                Picker("Player", selection: $selectedPlayer) {
                    ForEach(players, id: \.self) { player in
                        VStack(alignment: .leading) {
                            Text(player.username ?? "Unknown")
                            if let staffLabel = staffLabel(for: player) {
                                Text(staffLabel)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        .tag(Optional(player))
                    }
                }

                if players.isEmpty {
                    Text("No Competitive members yet — games can only be recorded for Competitive membership.")
                        .font(.caption)
                        .foregroundColor(.gray)
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
                    Label(message, systemImage: messageIsError ? "xmark.circle.fill" : "checkmark.circle.fill")
                        .foregroundColor(messageIsError ? .red : .green)
                }
            }

            Section(header: Text("Batch Upload (CSV)")) {
                Text("Required columns: \(Self.requiredCSVColumns.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundColor(.gray)

                Button("Choose CSV File") {
                    showFileImporter = true
                }
                .buttonStyle(.bordered)

                if !csvSummary.isEmpty {
                    Text(csvSummary)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color("AppBackground").ignoresSafeArea())
        .navigationTitle("Add Game")
        .alert(item: $promotionMessage) { alert in
            Alert(title: Text("Rank Change!"), message: Text(alert.message), dismissButton: .default(Text("OK")))
        }
        .alert(item: $csvAlert) { alert in
            Alert(title: Text(alert.title), message: Text(alert.message), dismissButton: .default(Text("OK")))
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.commaSeparatedText, .plainText],
            onCompletion: handleCSVImport
        )
    }

    private func submitGame() {
        guard let player = selectedPlayer,
              let p = Int64(points),
              let r = Int64(rebounds),
              let a = Int64(assists),
              let b = Int64(blocks),
              let s = Int64(steals)
        else {
            messageIsError = true
            message = "Please fill out all fields and select a player."
            return
        }

        if let boundsError = GameStatBounds.validate(points: p, rebounds: r, assists: a, blocks: b, steals: s) {
            messageIsError = true
            message = boundsError
            return
        }

        guard let result = recordGame(for: player, points: p, rebounds: r, assists: a, blocks: b, steals: s) else {
            messageIsError = true
            message = "\(player.username ?? "This player") is a Casual member — games are only recorded for Competitive members."
            return
        }

        if result.rankChanged {
            let rankMessage = result.gain > 0 ? "Promoted to \(result.newRank)!" : "Demoted to \(result.newRank)."
            promotionMessage = PromotionAlert(message: rankMessage)
        }

        do {
            try viewContext.save()
            messageIsError = false
            message = "Game recorded. \(result.gain >= 0 ? "+" : "")\(result.gain) RP."
            clearFields()
        } catch {
            messageIsError = true
            message = "Failed to save game: \(error.localizedDescription)"
        }
    }

    /// Creates the Game record, applies the RP gain/loss, and records a RankChange if the
    /// player's tier moved. Shared by the single-game form and the CSV batch importer so both
    /// paths always compute rank the same way. Returns `nil` — and creates nothing — for a
    /// non-Competitive player: this app's game history is Competitive-only.
    @discardableResult
    private func recordGame(
        for player: Player, points: Int64, rebounds: Int64, assists: Int64, blocks: Int64, steals: Int64
    ) -> (gain: Int64, rankChanged: Bool, newRank: String)? {
        guard AppConstants.isRanked(player.membership) else { return nil }

        let game = Game(context: viewContext)
        game.points = points
        game.rebounds = rebounds
        game.assists = assists
        game.blocks = blocks
        game.steals = steals
        game.date = Date()
        game.player = player

        let currentRank = RankSystem.rankName(for: player.rankPoints)
        let gain = RankSystem.rpGain(points: points, rebounds: rebounds, assists: assists, blocks: blocks, steals: steals, at: currentRank)

        let oldPoints = player.rankPoints
        player.rankPoints = max(0, oldPoints + gain)
        // The actual applied change can differ from `gain` when the 0-floor clamps it —
        // store the real delta so deleting/editing this game can reverse it exactly.
        game.rpDelta = player.rankPoints - oldPoints
        let newRank = RankSystem.rankName(for: player.rankPoints)

        var rankChanged = false
        if newRank != currentRank {
            let change = RankChange(context: viewContext)
            change.id = UUID()
            change.date = Date()
            change.newRank = newRank
            change.player = player
            player.lastRank = newRank
            rankChanged = true
        }

        return (game.rpDelta, rankChanged, newRank)
    }

    private func handleCSVImport(_ result: Result<URL, Error>) {
        switch result {
        case .failure(let error):
            finishCSVImport(title: "Import Failed", message: "Couldn't open file: \(error.localizedDescription)")
        case .success(let url):
            importCSV(from: url)
        }
    }

    /// Surfaces the outcome two ways: an alert (so it's impossible to miss that something
    /// happened) and a persistent inline summary (so the detail — e.g. which rows were
    /// skipped — is still there after the alert is dismissed).
    private func finishCSVImport(title: String, message: String) {
        csvSummary = message
        csvAlert = CSVImportAlert(title: title, message: message)
    }

    private func importCSV(from url: URL) {
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer { if didStartAccessing { url.stopAccessingSecurityScopedResource() } }

        guard let contents = try? String(contentsOf: url, encoding: .utf8) else {
            finishCSVImport(title: "Import Failed", message: "Couldn't read that file as text.")
            return
        }

        let lines = contents.split(whereSeparator: \.isNewline).map(String.init)
        guard let headerLine = lines.first else {
            finishCSVImport(title: "Import Failed", message: "File is empty.")
            return
        }

        let headers = headerLine.split(separator: ",", omittingEmptySubsequences: false)
            .map { Self.cleanField(String($0)).lowercased() }

        let missingColumns = Self.requiredCSVColumns.filter { !headers.contains($0) }
        guard missingColumns.isEmpty else {
            finishCSVImport(
                title: "Import Failed",
                message: "CSV is missing required column(s): \(missingColumns.joined(separator: ", "))."
            )
            return
        }

        var columnIndex: [String: Int] = [:]
        for (index, header) in headers.enumerated() {
            columnIndex[header] = index
        }

        var recordedCount = 0
        var rowErrors: [String] = []

        for (offset, rawLine) in lines.dropFirst().enumerated() {
            let displayRow = offset + 2  // +1 for the header row, +1 for 1-based row numbers
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }

            let fields = line.split(separator: ",", omittingEmptySubsequences: false)
                .map { Self.cleanField(String($0)) }

            guard
                let usernameIdx = columnIndex["username"], usernameIdx < fields.count,
                let pointsIdx = columnIndex["points"], pointsIdx < fields.count,
                let reboundsIdx = columnIndex["rebounds"], reboundsIdx < fields.count,
                let assistsIdx = columnIndex["assists"], assistsIdx < fields.count,
                let blocksIdx = columnIndex["blocks"], blocksIdx < fields.count,
                let stealsIdx = columnIndex["steals"], stealsIdx < fields.count
            else {
                rowErrors.append("Row \(displayRow): fewer columns than the header row.")
                continue
            }

            let username = fields[usernameIdx]
            guard !username.isEmpty else {
                rowErrors.append("Row \(displayRow): missing username.")
                continue
            }

            guard let p = Int64(fields[pointsIdx]),
                  let r = Int64(fields[reboundsIdx]),
                  let a = Int64(fields[assistsIdx]),
                  let b = Int64(fields[blocksIdx]),
                  let s = Int64(fields[stealsIdx])
            else {
                rowErrors.append("Row \(displayRow): stats must be whole numbers.")
                continue
            }

            if let boundsError = GameStatBounds.validate(points: p, rebounds: r, assists: a, blocks: b, steals: s) {
                rowErrors.append("Row \(displayRow): \(boundsError)")
                continue
            }

            let fetchRequest: NSFetchRequest<Player> = Player.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "username ==[c] %@", username)
            fetchRequest.fetchLimit = 1

            guard let player = try? viewContext.fetch(fetchRequest).first else {
                rowErrors.append("Row \(displayRow): no player found with username '\(username)'.")
                continue
            }

            guard recordGame(for: player, points: p, rebounds: r, assists: a, blocks: b, steals: s) != nil else {
                rowErrors.append("Row \(displayRow): '\(username)' is a Casual member — no game recorded.")
                continue
            }
            recordedCount += 1
        }

        if recordedCount > 0 {
            do {
                try viewContext.save()
            } catch {
                rowErrors.append("Save failed: \(error.localizedDescription)")
                recordedCount = 0
            }
        }

        var summary = "\(recordedCount) game(s) recorded from CSV."
        if !rowErrors.isEmpty {
            let shown = rowErrors.prefix(10)
            summary += " \(rowErrors.count) row(s) skipped:\n" + shown.joined(separator: "\n")
            if rowErrors.count > shown.count {
                summary += "\n…and \(rowErrors.count - shown.count) more."
            }
        }
        finishCSVImport(title: recordedCount > 0 ? "Import Complete" : "Nothing Imported", message: summary)
    }

    private static func cleanField(_ field: String) -> String {
        field.trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
    }

    private func staffLabel(for player: Player) -> String? {
        switch player.role {
        case AppConstants.employeeRole: return "Employee"
        case AppConstants.administratorRole: return "Administrator"
        default: return nil
        }
    }

    private func clearFields() {
        points = ""
        rebounds = ""
        assists = ""
        blocks = ""
        steals = ""
    }
}
