import SwiftUI
import EventKit
import EventKitUI

// Player-facing game night screens. All data comes through `GameNightStore`.

/// Who is looking at a game night: decides the RSVP card and the staff Roster link.
struct NightViewer: Hashable {
    let username: String
    let membership: String?
    let isStaff: Bool

    init(username: String, membership: String?, isStaff: Bool) {
        self.username = username; self.membership = membership; self.isStaff = isStaff
    }

    init?(_ player: Player?) {
        guard let player, let username = player.username else { return nil }
        self.init(username: username, membership: player.membership, isStaff: AppConstants.isStaff(player.role))
    }
}

/// "Upcoming Game Nights" preview on the dashboard: the next few nights and a link to all.
struct UpcomingGameNightsSection: View {
    var viewer: NightViewer? = nil

    @Environment(\.gameNightStore) private var store
    @State private var nights: [GameNightRecord] = []
    @State private var myStates: [UUID: MyRSVPState] = [:]
    @State private var loadError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Upcoming Game Nights").font(.headline)
                Spacer()
                if !nights.isEmpty {
                    NavigationLink("See all", value: DashboardRoute.upcomingGameNights)
                        .font(.subheadline)
                }
            }

            if let loadError {
                Text(loadError).font(.caption).foregroundColor(.red)
            } else if nights.isEmpty {
                Text("No game nights scheduled yet. Check back soon. New nights show up here with the time and place.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .cardStyle()
            } else {
                ForEach(nights.prefix(LeagueSettings.dashboardUpcomingCount)) { night in
                    NavigationLink(value: DashboardRoute.gameNight(id: night.id)) {
                        GameNightRow(night: night, myState: myStates[night.id])
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .onAppear(perform: load)
    }

    private func load() {
        do {
            nights = try store.upcomingGameNights(now: Date())
            myStates = Self.myStates(for: nights, viewer: viewer, store: store)
            loadError = nil
        } catch {
            loadError = "Couldn't load game nights: \(error.localizedDescription)"
        }
    }

    static func myStates(for nights: [GameNightRecord], viewer: NightViewer?, store: GameNightStore) -> [UUID: MyRSVPState] {
        guard let viewer else { return [:] }
        var states: [UUID: MyRSVPState] = [:]
        for night in nights {
            if let state = try? store.myRSVP(nightID: night.id, username: viewer.username) { states[night.id] = state }
        }
        return states
    }
}

/// One game night as a card: when, where, capacity, status.
struct GameNightRow: View {
    let night: GameNightRecord
    var myState: MyRSVPState? = nil

    var body: some View {
        let status = night.displayStatus()
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Text(monthAbbrev).font(.caption2).bold().foregroundColor(.red)
                Text(dayNumber).font(.title2).bold()
            }
            .frame(width: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(GameNightFormat.dayAndTimes(night))
                    .font(.subheadline).bold()
                    .strikethrough(status == .cancelled)
                Text(night.venue.name).font(.subheadline)
                Text(night.venue.shortAddress).font(.caption).foregroundColor(.secondary)
                HStack(spacing: 8) {
                    if status != .scheduled {
                        StatusBadge(status: status)
                    }
                    if let badge = MyRSVPBadge(state: myState) { badge }
                    if status == .scheduled || status == .full {
                        Text(night.availabilityText).font(.caption).foregroundColor(.secondary)
                    }
                }
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundColor(.secondary).font(.caption)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("gameNightRow")
    }

    private var monthAbbrev: String {
        let f = DateFormatter(); f.timeZone = LeagueSettings.timeZone; f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "MMM"
        return f.string(from: night.startDate).uppercased()
    }
    private var dayNumber: String {
        String(LeagueSettings.calendar.component(.day, from: night.startDate))
    }
}

/// "You're in" / "Waitlist #2" next to a night.
struct MyRSVPBadge: View {
    let text: String
    let color: Color

    init?(state: MyRSVPState?) {
        switch state {
        case .confirmed(let checkedIn):
            text = checkedIn ? "Checked in" : "You're in"; color = .green
        case .waitlisted(let position):
            text = "Waitlist #\(position)"; color = .orange
        case .none, nil:
            return nil
        }
    }

    var body: some View {
        Text(text)
            .font(.caption).bold()
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .clipShape(Capsule())
    }
}

struct StatusBadge: View {
    let status: GameNightStatus

    var body: some View {
        Text(status.label)
            .font(.caption).bold()
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .clipShape(Capsule())
    }

    private var color: Color {
        switch status {
        case .scheduled: return .blue
        case .full: return .orange
        case .cancelled: return .red
        case .completed: return .gray
        }
    }
}

/// All upcoming game nights.
struct UpcomingGameNightsView: View {
    var viewer: NightViewer? = nil

    @Environment(\.gameNightStore) private var store
    @State private var nights: [GameNightRecord] = []
    @State private var myStates: [UUID: MyRSVPState] = [:]

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if nights.isEmpty {
                    Text("No game nights scheduled yet.")
                        .foregroundColor(.secondary)
                        .padding(.top, 40)
                }
                ForEach(nights) { night in
                    NavigationLink(value: DashboardRoute.gameNight(id: night.id)) {
                        GameNightRow(night: night, myState: myStates[night.id])
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .background(Color("AppBackground").ignoresSafeArea())
        .navigationTitle("Game Nights")
        .onAppear {
            nights = (try? store.upcomingGameNights(now: Date())) ?? []
            myStates = UpcomingGameNightsSection.myStates(for: nights, viewer: viewer, store: store)
        }
    }
}

/// One game night: when, where, venue notes, and Open in Maps / Add to Calendar / Share.
struct GameNightDetailView: View {
    let nightID: UUID
    var viewer: NightViewer? = nil

    @Environment(\.gameNightStore) private var store
    @Environment(\.openURL) private var openURL
    @State private var night: GameNightRecord?
    @State private var myState: MyRSVPState = .none
    @State private var rsvpMessage: String?
    @State private var confirmCancelRSVP = false
    @State private var showCalendar = false
    @State private var calendarMessage: String?

    var body: some View {
        ScrollView {
            if let night {
                content(night)
                    .padding()
            } else {
                Text("This game night no longer exists.")
                    .foregroundColor(.secondary)
                    .padding(.top, 40)
            }
        }
        .background(Color("AppBackground").ignoresSafeArea())
        .navigationTitle("Game Night")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: load)
        .alert("RSVP", isPresented: Binding(get: { rsvpMessage != nil }, set: { if !$0 { rsvpMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(rsvpMessage ?? "")
        }
        .confirmationDialog("Cancel your RSVP?", isPresented: $confirmCancelRSVP, titleVisibility: .visible) {
            Button("Cancel RSVP", role: .destructive, action: cancelRSVP)
                .accessibilityIdentifier("confirmCancelRSVP")
            Button("Keep My Spot", role: .cancel) {}
        } message: {
            Text("If you change your mind later you'll go to the back of the line.")
        }
        .sheet(isPresented: $showCalendar) {
            if let night {
                CalendarEventEditor(night: night) { message in
                    showCalendar = false
                    calendarMessage = message
                }
                .ignoresSafeArea()
            }
        }
        .alert("Calendar", isPresented: Binding(get: { calendarMessage != nil }, set: { if !$0 { calendarMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(calendarMessage ?? "")
        }
    }

    @ViewBuilder
    private func content(_ night: GameNightRecord) -> some View {
        let status = night.displayStatus()
        VStack(alignment: .leading, spacing: 18) {
            if status == .cancelled {
                Label("This game night is cancelled.", systemImage: "xmark.octagon.fill")
                    .font(.headline)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(GameNightFormat.day(night.startDate))
                    .font(.title).bold()
                Text("\(GameNightFormat.time(night.startDate)) – \(GameNightFormat.time(night.endDate))")
                    .font(.title3)
                Text("San Antonio time")
                    .font(.caption)
                    .foregroundColor(.secondary)
                if status != .scheduled { StatusBadge(status: status) }
            }

            if let viewer { rsvpCard(night, viewer: viewer) }

            VStack(alignment: .leading, spacing: 6) {
                Label(night.venue.name, systemImage: "mappin.and.ellipse").font(.headline)
                Text(night.venue.address).foregroundColor(.secondary)
                if !night.venue.notes.isEmpty {
                    Label(night.venue.notes, systemImage: "info.circle")
                        .font(.subheadline)
                        .padding(.top, 4)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Label("\(night.availabilityText) · \(night.courtsInUse) court\(night.courtsInUse == 1 ? "" : "s")", systemImage: "person.3")
                if let season = night.seasonName {
                    Label(season, systemImage: "trophy")
                }
                if !night.notes.isEmpty {
                    Label(night.notes, systemImage: "text.bubble")
                }
            }
            .font(.subheadline)

            VStack(spacing: 10) {
                if let url = night.venue.mapsURL {
                    Button {
                        openURL(url)
                    } label: {
                        Label("Open in Maps", systemImage: "map").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }

                if status != .cancelled && status != .completed {
                    Button {
                        showCalendar = true
                    } label: {
                        Label("Add to Calendar", systemImage: "calendar.badge.plus").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

                ShareLink(item: GameNightFormat.shareText(night)) {
                    Label("Share", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding(.top, 6)
        }
    }

    // MARK: RSVP

    @ViewBuilder
    private func rsvpCard(_ night: GameNightRecord, viewer: NightViewer) -> some View {
        let refusal = RSVPPolicy.refusalToRSVP(night: night, membership: viewer.membership,
                                               alreadyActive: myState != .none, now: Date())
        VStack(alignment: .leading, spacing: 10) {
            switch myState {
            case .confirmed(let checkedIn):
                Label(checkedIn ? "You're checked in. Have a good run!" : "You're in.", systemImage: "checkmark.seal.fill")
                    .font(.headline).foregroundColor(.green)
                    .accessibilityIdentifier("rsvpState")
                if !checkedIn && night.displayStatus() != .completed {
                    Text("Check in with staff when you get there. Can't make it? Cancel so someone on the waitlist gets your spot.")
                        .font(.caption).foregroundColor(.secondary)
                    cancelButton
                }
            case .waitlisted(let position):
                Label("You're #\(position) on the waitlist.", systemImage: "hourglass")
                    .font(.headline).foregroundColor(.orange)
                    .accessibilityIdentifier("rsvpState")
                Text("If a spot opens up you move in automatically.")
                    .font(.caption).foregroundColor(.secondary)
                cancelButton
            case .none:
                if let refusal, refusal != .alreadyIn {
                    Label(refusal.localizedDescription, systemImage: "info.circle")
                        .font(.subheadline).foregroundColor(.secondary)
                        .accessibilityIdentifier("rsvpState")
                } else {
                    Button(action: rsvp) {
                        Label(night.spotsLeft > 0 ? "RSVP" : "Join Waitlist", systemImage: "hand.raised.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(night.spotsLeft > 0 ? .green : .orange)
                    .accessibilityIdentifier("rsvpButton")
                    Text("RSVPs close \(GameNightFormat.day(RSVPPolicy.rsvpDeadline(for: night))) at \(GameNightFormat.time(RSVPPolicy.rsvpDeadline(for: night))).")
                        .font(.caption).foregroundColor(.secondary)
                }
            }
            if viewer.isStaff {
                NavigationLink(value: DashboardRoute.roster(nightID: night.id)) {
                    Label("Roster & Check-in", systemImage: "list.bullet.clipboard").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("openRoster")
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var cancelButton: some View {
        Button(role: .destructive) {
            confirmCancelRSVP = true
        } label: {
            Text("Cancel RSVP").frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .accessibilityIdentifier("cancelRSVP")
    }

    private func load() {
        night = try? store.gameNight(id: nightID)
        if let viewer { myState = (try? store.myRSVP(nightID: nightID, username: viewer.username)) ?? .none }
    }

    private func rsvp() {
        guard let viewer else { return }
        do {
            let status = try store.rsvp(nightID: nightID, username: viewer.username, now: Date())
            load()
            if status == .waitlisted, case .waitlisted(let position) = myState {
                rsvpMessage = "The night is full, so you're #\(position) on the waitlist. You'll move in automatically if a spot opens."
            }
        } catch {
            rsvpMessage = error.localizedDescription
        }
    }

    private func cancelRSVP() {
        guard let viewer else { return }
        do {
            try store.cancelRSVP(nightID: nightID, username: viewer.username, now: Date())
            load()
        } catch {
            rsvpMessage = error.localizedDescription
        }
    }
}

/// The system "New Event" sheet, prefilled with the game night. On iOS 17+ this needs no
/// calendar permission (the user saves it themselves); on iOS 16 we ask for access first.
struct CalendarEventEditor: UIViewControllerRepresentable {
    let night: GameNightRecord
    let onFinish: (String?) -> Void

    private static let eventStore = EKEventStore()

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    func makeUIViewController(context: Context) -> UIViewController {
        let editor = EKEventEditViewController()
        editor.eventStore = Self.eventStore
        editor.editViewDelegate = context.coordinator

        let event = EKEvent(eventStore: Self.eventStore)
        event.title = night.isCancelled ? "TOTL Game Night (cancelled)" : "TOTL Game Night"
        event.startDate = night.startDate
        event.endDate = night.endDate
        event.timeZone = LeagueSettings.timeZone
        event.location = "\(night.venue.name), \(night.venue.address)"
        var notes = [String]()
        if !night.venue.notes.isEmpty { notes.append(night.venue.notes) }
        if !night.notes.isEmpty { notes.append(night.notes) }
        event.notes = notes.isEmpty ? nil : notes.joined(separator: "\n")
        event.url = night.venue.mapsURL
        editor.event = event

        if #unavailable(iOS 17) {
            Self.eventStore.requestAccess(to: .event) { granted, _ in
                if !granted {
                    DispatchQueue.main.async {
                        onFinish("Allow calendar access for TOTL in Settings to add game nights to your calendar.")
                    }
                }
            }
        }
        return editor
    }

    func updateUIViewController(_ controller: UIViewController, context: Context) {}

    final class Coordinator: NSObject, EKEventEditViewDelegate {
        let onFinish: (String?) -> Void
        init(onFinish: @escaping (String?) -> Void) { self.onFinish = onFinish }

        func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
            onFinish(action == .saved ? "Added to your calendar." : nil)
        }
    }
}
