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
    @State private var pickingTeam: Team?
    @State private var winner: Team = .a
    @State private var message = ""
    @State private var messageIsError = false
    @State private var resultAlert: CSVImportAlert? = nil

    @State private var showFileImporter = false
    @State private var csvSummary = ""


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
                    addPlayerButton(for: team)
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
        .toolbar {
            // Number pads have no Return key; this lets staff dismiss the keyboard.
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
        }
        .alert(item: $resultAlert) { alert in
            Alert(title: Text(alert.title), message: Text(alert.message), dismissButton: .default(Text("OK")))
        }
        .sheet(item: $pickingTeam) { team in
            PlayerPickerSheet(team: team, players: availablePlayers) { player in
                drafts.append(Draft(player: player, team: team))
            }
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

    private var availablePlayers: [Player] {
        let taken = Set(drafts.map { $0.player.objectID })
        return players.filter { !taken.contains($0.objectID) }
    }

    private func addPlayerButton(for team: Team) -> some View {
        Button {
            pickingTeam = team
        } label: {
            Label("Add Player", systemImage: "plus.circle")
        }
        .disabled(availablePlayers.isEmpty)
        .accessibilityIdentifier("addPlayer-\(team.rawValue)")
    }

    @ViewBuilder
    private var csvSection: some View {
        Section(header: Text("Batch Upload (CSV)")) {
            Text("Columns: \(GameCSVImporter.requiredColumns.joined(separator: ", ")), and optionally date (YYYY-MM-DD). One row per player. Rows with the same \"game\" value are one game. team is A or B, result is W or L. Games are recorded oldest first.")
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
        let bonus = results.map(\.underdogBonus).max() ?? 0
        let underdogNote = bonus > 0 ? "Underdog win! Each winner got +\(bonus) RP extra.\n\n" : ""
        return underdogNote + results
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

    private func importCSV(from url: URL) {
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer { if didStartAccessing { url.stopAccessingSecurityScopedResource() } }
        guard let contents = try? String(contentsOf: url, encoding: .utf8) else {
            finishCSVImport(title: "Import Failed", message: "Couldn't read that file as text.")
            return
        }
        let result = GameCSVImporter.importCSV(contents, in: viewContext)
        finishCSVImport(title: result.recorded > 0 ? "Import Complete" : "Nothing Imported", message: result.summary)
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
                .accessibilityIdentifier("stat-\(draft.player.username ?? "")-\(label)")
                .multilineTextAlignment(.center)
                .textFieldStyle(.roundedBorder)
        }
    }
}

/// Searchable list of Competitive players not yet in this game. Tapping one adds them to the
/// team and closes the sheet.
private struct PlayerPickerSheet: View {
    let team: Team
    let players: [Player]
    let onPick: (Player) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    private var filtered: [Player] {
        guard !search.isEmpty else { return players }
        return players.filter { $0.username?.localizedCaseInsensitiveContains(search) ?? false }
    }

    var body: some View {
        NavigationStack {
            List(filtered, id: \.objectID) { player in
                Button {
                    onPick(player)
                    dismiss()
                } label: {
                    HStack {
                        Text(player.username ?? "Unknown")
                            .foregroundColor(.primary)
                        Spacer()
                        Text(player.placementGamesRemaining > 0
                             ? "Placement"
                             : RankSystem.rankName(for: player.rankPoints))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .accessibilityIdentifier("pick-\(player.username ?? "")")
            }
            .searchable(text: $search, prompt: "Search players")
            .navigationTitle("Add to \(team.displayName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .overlay {
                if filtered.isEmpty {
                    Text("No players match.").foregroundColor(.secondary)
                }
            }
        }
    }
}
