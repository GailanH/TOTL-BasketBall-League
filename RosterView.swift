import SwiftUI

// Staff: one game night's roster. Check players in, add walk-ins, pick the next game's players,
// get balanced teams, and open Record Game already filled in and linked to the night.

/// What Record Game needs to start pre-filled from a game night.
struct GamePrefill: Hashable {
    let nightID: UUID
    let teamA: [String]
    let teamB: [String]
}

struct RosterView: View {
    let nightID: UUID
    let staffUsername: String?

    @Environment(\.gameNightStore) private var store
    @State private var night: GameNightRecord?
    @State private var roster: Roster = .empty
    @State private var played: [String: Int] = [:]
    @State private var selected: Set<String> = []
    @State private var split: TeamSplit?
    @State private var errorMessage: String?
    @State private var showWalkIns = false
    @State private var editing = false

    /// Teams as usernames so staff can move players between them.
    struct TeamSplit: Equatable {
        var teamA: [String]
        var teamB: [String]
    }

    var body: some View {
        List {
            if let night {
                headerSection(night)
                checkInSection(night)
                if !roster.waitlist.isEmpty { waitlistSection }
                nextGameSection
            } else {
                Text("This game night no longer exists.").foregroundColor(.secondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color("AppBackground").ignoresSafeArea())
        .navigationTitle("Roster")
        .toolbar {
            if night != nil {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Edit") { editing = true }
                        .accessibilityIdentifier("editGameNight")
                }
            }
        }
        .onAppear(perform: load)
        .sheet(isPresented: $editing, onDismiss: load) {
            if let night {
                GameNightEditorView(night: night, isNew: false, staffUsername: staffUsername)
            }
        }
        .sheet(isPresented: $showWalkIns, onDismiss: load) {
            WalkInPickerSheet(nightID: nightID)
        }
        .alert("Roster", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: Sections

    private func headerSection(_ night: GameNightRecord) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Text(GameNightFormat.dayAndTimes(night)).font(.headline)
                    .strikethrough(night.isCancelled)
                Text(night.venue.name).font(.subheadline)
                HStack {
                    if night.displayStatus() != .scheduled { StatusBadge(status: night.displayStatus()) }
                    Text(night.availabilityText).font(.caption).foregroundColor(.secondary)
                        .accessibilityIdentifier("rosterAvailability")
                }
                Text(checkInNote(night)).font(.caption).foregroundColor(.secondary)
            }
        }
    }

    private func checkInSection(_ night: GameNightRecord) -> some View {
        Section(header: Text("Players (\(roster.checkedIn.count) of \(roster.confirmed.count) checked in)")) {
            if roster.confirmed.isEmpty {
                Text("No RSVPs yet.").foregroundColor(.secondary)
            }
            ForEach(roster.confirmed) { rsvp in
                confirmedRow(rsvp)
            }
            Button {
                showWalkIns = true
            } label: {
                Label("Add Walk-in", systemImage: "person.badge.plus")
            }
            .disabled(night.isCancelled || night.spotsLeft == 0)
            .accessibilityIdentifier("addWalkIn")
            if night.spotsLeft == 0 && !night.isCancelled {
                Text("The night is full. Raise the capacity (Edit) to add walk-ins.")
                    .font(.caption).foregroundColor(.secondary)
            }
        }
    }

    private func confirmedRow(_ rsvp: RSVPRecord) -> some View {
        HStack(spacing: 12) {
            Button {
                toggleCheckIn(rsvp)
            } label: {
                Image(systemName: rsvp.isCheckedIn ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(rsvp.isCheckedIn ? .green : .secondary)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(rsvp.isCheckedIn ? "Checked in \(rsvp.username)" : "Check in \(rsvp.username)")
            .accessibilityIdentifier("checkIn-\(rsvp.username)")

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(rsvp.username).font(.body)
                    if rsvp.isWalkIn {
                        Text("Walk-in").font(.caption2).bold()
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(Color.purple.opacity(0.15)).foregroundColor(.purple)
                            .clipShape(Capsule())
                    }
                }
                Text(caption(rsvp)).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            if rsvp.isCheckedIn {
                Button {
                    toggleSelection(rsvp.username)
                } label: {
                    Image(systemName: selected.contains(rsvp.username) ? "basketball.fill" : "basketball")
                        .foregroundColor(selected.contains(rsvp.username) ? .orange : .secondary)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(selected.contains(rsvp.username) ? "In next game: \(rsvp.username)" : "Add \(rsvp.username) to next game")
                .accessibilityIdentifier("select-\(rsvp.username)")
            }
        }
    }

    private var waitlistSection: some View {
        Section(header: Text("Waitlist (\(roster.waitlist.count))"),
                footer: Text("The first player in line moves up automatically when someone cancels or capacity goes up.")) {
            ForEach(Array(roster.waitlist.enumerated()), id: \.element.id) { index, rsvp in
                HStack {
                    Text("#\(index + 1)").font(.caption).bold().foregroundColor(.orange).frame(width: 28)
                    Text(rsvp.username)
                    Spacer()
                    Text(rsvp.rank).font(.caption).foregroundColor(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var nextGameSection: some View {
        let checkedIn = roster.checkedIn.map(\.username)
        Section(header: Text("Next Game (\(selected.count) selected)"),
                footer: Text("Tap the ball next to checked-in players to pick who plays next. Suggest Teams splits them by RP; tap a player to move them to the other team.")) {
            HStack {
                Button("Select All Checked In") {
                    selected = Set(checkedIn); split = nil
                }
                .disabled(checkedIn.isEmpty)
                .accessibilityIdentifier("selectAllCheckedIn")
                Spacer()
                if !selected.isEmpty {
                    Button("Clear") { selected = []; split = nil }
                }
            }
            .buttonStyle(.borderless)

            Button {
                suggestTeams()
            } label: {
                Label("Suggest Teams", systemImage: "scalemass")
            }
            .disabled(selected.count < 2)
            .accessibilityIdentifier("suggestTeams")

            if let split {
                teamList("Team A", split.teamA, toOther: true)
                teamList("Team B", split.teamB, toOther: false)
                Text(balanceText(split)).font(.caption).foregroundColor(.secondary)
                    .accessibilityIdentifier("teamBalance")
                NavigationLink(value: DashboardRoute.recordGame(GamePrefill(nightID: nightID, teamA: split.teamA, teamB: split.teamB))) {
                    Label("Record This Game", systemImage: "square.and.pencil").bold()
                }
                .disabled(split.teamA.isEmpty || split.teamB.isEmpty)
                .accessibilityIdentifier("recordThisGame")
            }
        }
    }

    private func teamList(_ title: String, _ members: [String], toOther fromA: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(title) · \(total(members)) RP").font(.subheadline).bold()
            ForEach(members, id: \.self) { name in
                Button {
                    move(name, fromA: fromA)
                } label: {
                    HStack {
                        Text(name)
                        Spacer()
                        Text(rankText(name)).font(.caption).foregroundColor(.secondary)
                        Image(systemName: fromA ? "arrow.down" : "arrow.up").font(.caption).foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.borderless)
                .foregroundColor(.primary)
                .accessibilityIdentifier("team-\(name)")
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: Actions

    private func load() {
        do {
            night = try store.gameNight(id: nightID)
            roster = try store.roster(nightID: nightID)
            played = try store.gamesPlayed(nightID: nightID)
            let checkedIn = Set(roster.checkedIn.map(\.username))
            selected = selected.intersection(checkedIn)
            if let current = split, !Set(current.teamA + current.teamB).isSubset(of: checkedIn) { split = nil }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func toggleCheckIn(_ rsvp: RSVPRecord) {
        do {
            try store.setCheckedIn(!rsvp.isCheckedIn, nightID: nightID, username: rsvp.username, now: Date())
            if rsvp.isCheckedIn { selected.remove(rsvp.username) }
            load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func toggleSelection(_ username: String) {
        if selected.contains(username) { selected.remove(username) } else { selected.insert(username) }
        split = nil
    }

    private func suggestTeams() {
        let players = roster.checkedIn
            .filter { selected.contains($0.username) }
            .map { TeamBalancer.Player(id: $0.username, rankPoints: $0.rankPoints) }
        let result = TeamBalancer.suggest(players)
        split = TeamSplit(teamA: result.teamA.map(\.id), teamB: result.teamB.map(\.id))
    }

    private func move(_ name: String, fromA: Bool) {
        guard var current = split else { return }
        if fromA {
            current.teamA.removeAll { $0 == name }; current.teamB.append(name)
        } else {
            current.teamB.removeAll { $0 == name }; current.teamA.append(name)
        }
        split = current
    }

    // MARK: Text

    private func rp(_ name: String) -> Int64 {
        roster.confirmed.first { $0.username == name }?.rankPoints ?? 0
    }
    private func total(_ names: [String]) -> Int64 { names.reduce(0) { $0 + rp($1) } }
    private func rankText(_ name: String) -> String {
        guard let r = roster.confirmed.first(where: { $0.username == name }) else { return "" }
        return r.placementGamesRemaining > 0 ? "Placement" : "\(r.rank) · \(r.rankPoints)"
    }

    private func caption(_ rsvp: RSVPRecord) -> String {
        var parts = [rsvp.placementGamesRemaining > 0 ? "Placement" : "\(rsvp.rank) · \(rsvp.rankPoints) RP"]
        if let games = played[rsvp.username], games > 0 { parts.append("played \(games)") }
        return parts.joined(separator: " · ")
    }

    private func balanceText(_ split: TeamSplit) -> String {
        let diff = abs(total(split.teamA) - total(split.teamB))
        let sizes = "\(split.teamA.count) v \(split.teamB.count)"
        return diff == 0 ? "\(sizes) · dead even on RP" : "\(sizes) · \(diff) RP apart"
    }

    private func checkInNote(_ night: GameNightRecord) -> String {
        if night.isCancelled { return "This night is cancelled." }
        if RSVPPolicy.checkInIsOpen(night: night, now: Date()) { return "Check-in is open." }
        let opens = night.startDate.addingTimeInterval(-LeagueSettings.checkInOpensBefore)
        if Date() < opens { return "Check-in opens at \(GameNightFormat.time(opens)). You can still check players in early." }
        return "This night is over."
    }
}

/// Staff: Competitive members not on tonight's list, to add as walk-ins (checked in right away).
struct WalkInPickerSheet: View {
    let nightID: UUID

    @Environment(\.gameNightStore) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var candidates: [MemberSummary] = []
    @State private var search = ""
    @State private var errorMessage: String?

    private var filtered: [MemberSummary] {
        search.isEmpty ? candidates : candidates.filter { $0.username.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { member in
                Button {
                    add(member.username)
                } label: {
                    HStack {
                        Text(member.username).foregroundColor(.primary)
                        Spacer()
                        Text(member.rank).font(.caption).foregroundColor(.secondary)
                    }
                }
                .accessibilityIdentifier("walkIn-\(member.username)")
            }
            .searchable(text: $search)
            .navigationTitle("Add Walk-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .onAppear { candidates = (try? store.walkInCandidates(nightID: nightID)) ?? [] }
            .alert("Walk-in", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func add(_ username: String) {
        do {
            try store.addWalkIn(nightID: nightID, username: username, now: Date())
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
