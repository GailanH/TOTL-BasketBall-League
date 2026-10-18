import SwiftUI
import CoreData
import UniformTypeIdentifiers

struct CSVImportAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

/// Staff screen for recording a ranked game: two teams, every player's stat line, and the
/// winner. Scoring (win/loss, MVP/SVP, placement, caps) happens in `MatchRecorder`.
struct AddGameView: View {
    @Environment(\.managedObjectContext) private var viewContext

    var employee: Player

    /// Ranked games are Competitive-only, so Casual members aren't offered.
    @FetchRequest(
        sortDescriptors: [SortDescriptor(\Player.username)],
        predicate: NSPredicate(format: "membership == %@", AppConstants.competitiveMembership),
        animation: .default
    ) private var players: FetchedResults<Player>

    struct Draft: Identifiable {
        let id = UUID()
        let player: Player
        var team: Team
        var points = ""
        var rebounds = ""
        var assists = ""
        var blocks = ""
        var steals = ""
    }

    @State private var drafts: [Draft] = []
    @State private var winner: Team = .a
    @State private var message = ""
    @State private var messageIsError = false
    @State private var resultAlert: CSVImportAlert? = nil

    @State private var showFileImporter = false
    @State private var csvSummary = ""

    private static let requiredCSVColumns = ["game", "username", "team", "result", "points", "rebounds", "assists", "blocks", "steals"]

    private var season: Season? { SeasonManager.activeSeason(in: viewContext) }

    var body: some View {
        Form {
            seasonSection

            ForEach(Team.allCases) { team in
                Section(header: Text(team.displayName)) {
                    ForEach(drafts.filter { $0.team == team }) { draft in
                        DraftRow(draft: binding(for: draft.id)) {
                            drafts.removeAll { $0.id == draft.id }
                        }
                    }
                    addPlayerMenu(for: team)
                }
            }

            Section(header: Text("Result")) {
                Picker("Winner", selection: $winner) {
                    ForEach(Team.allCases) { team in
                        Text("\(team.displayName) won").tag(team)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section {
                Button("Submit Game") { submitGame() }
                    .buttonStyle(.borderedProminent)
                    .disabled(drafts.isEmpty)
            }

            if !message.isEmpty {
                Section {
                    Label(message, systemImage: messageIsError ? "xmark.circle.fill" : "checkmark.circle.fill")
                        .foregroundColor(messageIsError ? .red : .green)
                }
            }

            csvSection
        }
        .scrollContentBackground(.hidden)
        .background(Color("AppBackground").ignoresSafeArea())
        .navigationTitle("Record Game")
        .alert(item: $resultAlert) { alert in
            Alert(title: Text(alert.title), message: Text(alert.message), dismissButton: .default(Text("OK")))
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.commaSeparatedText, .plainText],
            onCompletion: handleCSVImport
        )
    }

    // MARK: Sections

    @ViewBuilder
    private var seasonSection: some View {
        Section(header: Text("Season")) {
            if let season {
                Text(season.name ?? "Current Season")
                if SeasonManager.isPastScheduledEnd(season) {
                    Label("This season's 3 months are up. Start a new season from the Seasons screen.", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            } else {
                Text("Season 1 starts with the first recorded game.")
                    .foregroundColor(.secondary)
            }
        }
    }

    private func addPlayerMenu(for team: Team) -> some View {
        let taken = Set(drafts.map { $0.player.objectID })
        let available = players.filter { !taken.contains($0.objectID) }
        return Menu {
            ForEach(available, id: \.objectID) { player in
                Button(player.username ?? "Unknown") {
                    drafts.append(Draft(player: player, team: team))
                }
            }
        } label: {
            Label("Add Player", systemImage: "plus.circle")
        }
        .disabled(available.isEmpty)
    }

    @ViewBuilder
    private var csvSection: some View {
        Section(header: Text("Batch Upload (CSV)")) {
            Text("Columns: \(Self.requiredCSVColumns.joined(separator: ", ")). One row per player. Rows with the same \"game\" value are one game. team is A or B, result is W or L.")
                .font(.caption)
                .foregroundColor(.gray)

            Button("Choose CSV File") { showFileImporter = true }
                .buttonStyle(.bordered)

            if !csvSummary.isEmpty {
                Text(csvSummary)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func binding(for id: UUID) -> Binding<Draft> {
        Binding(
            get: { drafts.first { $0.id == id } ?? Draft(player: employee, team: .a) },
            set: { newValue in
                if let index = drafts.firstIndex(where: { $0.id == id }) { drafts[index] = newValue }
            }
        )
    }

    // MARK: Manual entry

    private func submitGame() {
        var entries: [MatchEntry] = []
        for draft in drafts {
            guard let p = Int64(draft.points), let r = Int64(draft.rebounds), let a = Int64(draft.assists),
                  let b = Int64(draft.blocks), let s = Int64(draft.steals) else {
                show(error: "Enter all five stats as whole numbers for \(draft.player.username ?? "every player").")
                return
            }
            entries.append(MatchEntry(player: draft.player, team: draft.team,
                                      stats: StatLine(points: p, rebounds: r, assists: a, blocks: b, steals: s)))
        }

        do {
            let results = try MatchRecorder.record(entries, winner: winner, in: viewContext)
            try viewContext.save()
            messageIsError = false
            message = "Game recorded."
            resultAlert = CSVImportAlert(title: "\(winner.displayName) Wins", message: Self.summary(of: results))
            drafts = []
        } catch {
            viewContext.rollback()
            show(error: error.localizedDescription)
        }
    }

    private func show(error: String) {
        messageIsError = true
        message = error
    }

    static func summary(of results: [MatchRecorder.PlayerResult]) -> String {
        results
            .sorted { ($0.won ? 0 : 1, -$0.rpDelta) < ($1.won ? 0 : 1, -$1.rpDelta) }
            .map { result in
                var line = "\(result.player.username ?? "?")"
                if let award = result.award { line += " (\(award.rawValue))" }
                line += ": \(result.rpDelta >= 0 ? "+" : "")\(result.rpDelta) RP"
                if result.rankChanged { line += ", now \(result.newRank)" }
                return line
            }
            .joined(separator: "\n")
    }

    // MARK: CSV

    private func handleCSVImport(_ result: Result<URL, Error>) {
        switch result {
        case .failure(let error):
            finishCSVImport(title: "Import Failed", message: "Couldn't open file: \(error.localizedDescription)")
        case .success(let url):
            importCSV(from: url)
        }
    }

    private func finishCSVImport(title: String, message: String) {
        csvSummary = message
        resultAlert = CSVImportAlert(title: title, message: message)
    }

    private struct CSVRow {
        let line: Int
        let username: String
        let team: Team
        let won: Bool
        let stats: StatLine
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
        let missing = Self.requiredCSVColumns.filter { !headers.contains($0) }
        guard missing.isEmpty else {
            finishCSVImport(title: "Import Failed", message: "CSV is missing required column(s): \(missing.joined(separator: ", ")).")
            return
        }
        var column: [String: Int] = [:]
        for (index, header) in headers.enumerated() { column[header] = index }

        var errors: [String] = []
        var gameOrder: [String] = []
        var rowsByGame: [String: [CSVRow]] = [:]
        var badGames = Set<String>()

        for (offset, rawLine) in lines.dropFirst().enumerated() {
            let lineNumber = offset + 2
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }
            let fields = line.split(separator: ",", omittingEmptySubsequences: false).map { Self.cleanField(String($0)) }
            func field(_ name: String) -> String? {
                guard let index = column[name], index < fields.count else { return nil }
                return fields[index]
            }

            guard let gameKey = field("game"), !gameKey.isEmpty else {
                errors.append("Row \(lineNumber): missing game.")
                continue
            }
            if rowsByGame[gameKey] == nil { gameOrder.append(gameKey); rowsByGame[gameKey] = [] }

            guard let username = field("username"), !username.isEmpty,
                  let team = field("team").flatMap({ Team(rawValue: $0.uppercased()) }),
                  let result = field("result")?.uppercased(), result == "W" || result == "L",
                  let p = field("points").flatMap({ Int64($0) }),
                  let r = field("rebounds").flatMap({ Int64($0) }),
                  let a = field("assists").flatMap({ Int64($0) }),
                  let b = field("blocks").flatMap({ Int64($0) }),
                  let s = field("steals").flatMap({ Int64($0) })
            else {
                errors.append("Row \(lineNumber): needs a username, team A/B, result W/L, and whole-number stats.")
                badGames.insert(gameKey)
                continue
            }
            rowsByGame[gameKey]?.append(CSVRow(line: lineNumber, username: username, team: team, won: result == "W",
                                               stats: StatLine(points: p, rebounds: r, assists: a, blocks: b, steals: s)))
        }

        var recorded = 0
        for gameKey in gameOrder {
            guard !badGames.contains(gameKey) else {
                errors.append("Game \(gameKey): skipped because of the row error(s) above.")
                continue
            }
            let rows = rowsByGame[gameKey] ?? []
            let winners = Set(rows.filter(\.won).map(\.team))
            let losers = Set(rows.filter { !$0.won }.map(\.team))
            guard winners.count == 1, let winner = winners.first, !losers.contains(winner) else {
                errors.append("Game \(gameKey): exactly one team must be W and the other L.")
                continue
            }

            var entries: [MatchEntry] = []
            var missingPlayer: String?
            for row in rows {
                let request: NSFetchRequest<Player> = Player.fetchRequest()
                request.predicate = NSPredicate(format: "username ==[c] %@", row.username)
                request.fetchLimit = 1
                guard let player = try? viewContext.fetch(request).first else { missingPlayer = row.username; break }
                entries.append(MatchEntry(player: player, team: row.team, stats: row.stats))
            }
            if let missingPlayer {
                errors.append("Game \(gameKey): no player found with username '\(missingPlayer)'.")
                continue
            }

            do {
                try MatchRecorder.record(entries, winner: winner, in: viewContext)
                recorded += 1
            } catch {
                errors.append("Game \(gameKey): \(error.localizedDescription)")
            }
        }

        if recorded > 0 {
            do {
                try viewContext.save()
            } catch {
                viewContext.rollback()
                errors.append("Save failed: \(error.localizedDescription)")
                recorded = 0
            }
        }

        var summary = "\(recorded) game(s) recorded from CSV."
        if !errors.isEmpty {
            let shown = errors.prefix(10)
            summary += " \(errors.count) problem(s):\n" + shown.joined(separator: "\n")
            if errors.count > shown.count { summary += "\n…and \(errors.count - shown.count) more." }
        }
        finishCSVImport(title: recorded > 0 ? "Import Complete" : "Nothing Imported", message: summary)
    }

    private static func cleanField(_ field: String) -> String {
        field.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
    }
}

/// One player's stat entry inside the Record Game form.
private struct DraftRow: View {
    @Binding var draft: AddGameView.Draft
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(draft.player.username ?? "Unknown").font(.headline)
                    Text(rankCaption).font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                Button(role: .destructive, action: onRemove) {
                    Image(systemName: "minus.circle.fill")
                }
                .buttonStyle(.borderless)
            }
            HStack(spacing: 6) {
                statField("PTS", $draft.points)
                statField("REB", $draft.rebounds)
                statField("AST", $draft.assists)
                statField("BLK", $draft.blocks)
                statField("STL", $draft.steals)
            }
        }
        .padding(.vertical, 4)
    }

    private var rankCaption: String {
        let rank = RankSystem.rankName(for: draft.player.rankPoints)
        let left = draft.player.placementGamesRemaining
        return left > 0 ? "\(rank) · placement (\(left) left)" : "\(rank) · \(draft.player.rankPoints) RP"
    }

    private func statField(_ label: String, _ text: Binding<String>) -> some View {
        VStack(spacing: 2) {
            Text(label).font(.caption2).foregroundColor(.secondary)
            TextField("0", text: text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .textFieldStyle(.roundedBorder)
        }
    }
}
