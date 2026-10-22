import SwiftUI

// Staff screens for venues and game nights. All data goes through `GameNightStore`.

/// Staff: every game night (upcoming first, then past), plus New Game Night and Venues.
struct ManageGameNightsView: View {
    let staffUsername: String?

    @Environment(\.gameNightStore) private var store
    @State private var nights: [GameNightRecord] = []
    @State private var activeVenues: [VenueRecord] = []
    @State private var editing: EditorTarget?

    struct EditorTarget: Identifiable {
        let id = UUID()
        let night: GameNightRecord
        let isNew: Bool
    }

    private var upcoming: [GameNightRecord] {
        nights.filter { $0.endDate >= Date() }.sorted { $0.startDate < $1.startDate }
    }
    private var past: [GameNightRecord] {
        nights.filter { $0.endDate < Date() }
    }

    var body: some View {
        List {
            Section {
                if activeVenues.isEmpty {
                    Text("Add a venue first. Game nights need a place.")
                        .foregroundColor(.secondary)
                } else {
                    Button {
                        let day = LeagueSettings.calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
                        editing = EditorTarget(night: .newNight(on: day, at: activeVenues[0]), isNew: true)
                    } label: {
                        Label("New Game Night", systemImage: "plus.circle.fill")
                    }
                    .accessibilityIdentifier("newGameNight")
                }
                NavigationLink(value: DashboardRoute.venues) {
                    Label("Venues", systemImage: "building.2")
                }
            }

            Section(header: Text("Upcoming")) {
                if upcoming.isEmpty {
                    Text("No upcoming game nights.").foregroundColor(.secondary)
                }
                ForEach(upcoming) { night in
                    row(night)
                }
            }

            if !past.isEmpty {
                Section(header: Text("Past")) {
                    ForEach(past) { night in row(night) }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color("AppBackground").ignoresSafeArea())
        .navigationTitle("Game Nights")
        .onAppear(perform: load)
        .sheet(item: $editing, onDismiss: load) { target in
            GameNightEditorView(night: target.night, isNew: target.isNew, staffUsername: staffUsername)
        }
    }

    private func row(_ night: GameNightRecord) -> some View {
        Button {
            editing = EditorTarget(night: night, isNew: false)
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(GameNightFormat.dayAndTimes(night)).font(.subheadline).bold()
                        .strikethrough(night.isCancelled)
                    Spacer()
                    if night.displayStatus() != .scheduled { StatusBadge(status: night.displayStatus()) }
                }
                Text("\(night.venue.name) · \(night.capacity) spots").font(.caption).foregroundColor(.secondary)
            }
            .foregroundColor(.primary)
        }
    }

    private func load() {
        nights = (try? store.allGameNights()) ?? []
        activeVenues = (try? store.venues(includeInactive: false)) ?? []
    }
}

/// Staff: create or edit a game night, or cancel it. Times are entered in league time.
struct GameNightEditorView: View {
    @State var night: GameNightRecord
    let isNew: Bool
    let staffUsername: String?

    @Environment(\.gameNightStore) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var venues: [VenueRecord] = []
    @State private var errorMessage: String?
    @State private var confirmCancel = false
    @State private var capacityText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Where")) {
                    Picker("Venue", selection: $night.venue) {
                        ForEach(venueChoices) { venue in
                            Text(venue.isActive ? venue.name : "\(venue.name) (inactive)").tag(venue)
                        }
                    }
                    if !night.venue.address.isEmpty {
                        Text(night.venue.address).font(.caption).foregroundColor(.secondary)
                    }
                    Stepper("Courts: \(night.courtsInUse) of \(night.venue.courtCount)",
                            value: $night.courtsInUse, in: 1...max(1, night.venue.courtCount))
                }

                Section(header: Text("When (San Antonio time)")) {
                    DatePicker("Starts", selection: $night.startDate)
                        .onChange(of: night.startDate) { newStart in
                            // Keep the same length when the start moves.
                            if night.endDate <= newStart {
                                night.endDate = newStart.addingTimeInterval(LeagueSettings.defaultDuration)
                            }
                        }
                    DatePicker("Ends", selection: $night.endDate, in: night.startDate...)
                }
                .environment(\.timeZone, LeagueSettings.timeZone)

                Section(header: Text("Players")) {
                    HStack {
                        Text("Capacity")
                        Spacer()
                        TextField("20", text: $capacityText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                            .accessibilityIdentifier("capacityField")
                    }
                    TextField("Notes for players (optional)", text: $night.notes, axis: .vertical)
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "xmark.circle.fill").foregroundColor(.red)
                    }
                }

                if !isNew && !night.isCancelled {
                    Section {
                        Button("Cancel This Game Night", role: .destructive) { confirmCancel = true }
                    } footer: {
                        Text("Players who were planning to come will be told it's cancelled once notifications are set up.")
                    }
                }
            }
            .navigationTitle(isNew ? "New Game Night" : "Edit Game Night")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isNew ? "Create" : "Save") { save() }
                        .accessibilityIdentifier("saveGameNight")
                }
            }
            .confirmationDialog("Cancel this game night?", isPresented: $confirmCancel, titleVisibility: .visible) {
                Button("Cancel Game Night", role: .destructive) { cancelNight() }
                Button("Keep It", role: .cancel) {}
            }
            .onAppear {
                venues = (try? store.venues(includeInactive: true)) ?? []
                capacityText = String(night.capacity)
            }
        }
    }

    /// Active venues, plus this night's venue even if it has since been deactivated.
    private var venueChoices: [VenueRecord] {
        var choices = venues.filter(\.isActive)
        if !choices.contains(where: { $0.id == night.venue.id }) { choices.insert(night.venue, at: 0) }
        return choices
    }

    private func save() {
        guard let capacity = Int16(capacityText) else {
            errorMessage = "Capacity has to be a whole number."
            return
        }
        night.capacity = capacity
        night.courtsInUse = min(night.courtsInUse, night.venue.courtCount)
        do {
            try store.saveGameNight(night, createdBy: isNew ? staffUsername : nil)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func cancelNight() {
        do {
            try store.cancelGameNight(id: night.id)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// Staff: the list of venues.
struct VenuesView: View {
    @Environment(\.gameNightStore) private var store
    @State private var venues: [VenueRecord] = []
    @State private var editing: VenueRecord?

    var body: some View {
        List {
            Section {
                Button {
                    editing = VenueRecord()
                } label: {
                    Label("Add Venue", systemImage: "plus.circle.fill")
                }
                .accessibilityIdentifier("addVenue")
            }
            Section {
                if venues.isEmpty {
                    Text("No venues yet.").foregroundColor(.secondary)
                }
                ForEach(venues) { venue in
                    Button {
                        editing = venue
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(venue.name).font(.headline)
                                if !venue.isActive {
                                    Text("Inactive").font(.caption).foregroundColor(.secondary)
                                }
                            }
                            Text(venue.address).font(.caption).foregroundColor(.secondary)
                            Text("\(venue.courtCount) court\(venue.courtCount == 1 ? "" : "s")").font(.caption)
                        }
                        .foregroundColor(.primary)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color("AppBackground").ignoresSafeArea())
        .navigationTitle("Venues")
        .onAppear(perform: load)
        .sheet(item: $editing, onDismiss: load) { venue in
            VenueEditorView(venue: venue)
        }
    }

    private func load() {
        venues = (try? store.venues(includeInactive: true)) ?? []
    }
}

/// Staff: add or edit a venue.
struct VenueEditorView: View {
    @State var venue: VenueRecord

    @Environment(\.gameNightStore) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Venue")) {
                    TextField("Name", text: $venue.name)
                        .accessibilityIdentifier("venueName")
                    TextField("Address", text: $venue.address, axis: .vertical)
                        .textContentType(.fullStreetAddress)
                        .accessibilityIdentifier("venueAddress")
                    Stepper("Courts: \(venue.courtCount)", value: $venue.courtCount, in: 1...20)
                }
                Section(header: Text("For players"), footer: Text("Parking, which entrance, anything that helps players find the court.")) {
                    TextField("Notes (optional)", text: $venue.notes, axis: .vertical)
                    TextField("Map link (optional)", text: Binding(
                        get: { venue.mapURL ?? "" },
                        set: { venue.mapURL = $0.isEmpty ? nil : $0 }
                    ))
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                }
                Section {
                    Toggle("Active", isOn: $venue.isActive)
                } footer: {
                    Text("Inactive venues can't be picked for new game nights. Past nights keep their venue.")
                }
                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "xmark.circle.fill").foregroundColor(.red)
                    }
                }
            }
            .navigationTitle(venue.name.isEmpty ? "New Venue" : venue.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.accessibilityIdentifier("saveVenue")
                }
            }
        }
    }

    private func save() {
        do {
            try store.saveVenue(venue)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
