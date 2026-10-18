import SwiftUI
import CoreData

struct CoachingListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    var player: Player

    @FetchRequest(
        sortDescriptors: [SortDescriptor(\CoachingSession.date)],
        animation: .default
    ) private var sessions: FetchedResults<CoachingSession>

    @State private var showAddSheet = false
    @State private var sessionToEdit: CoachingSession?
    @State private var sessionToCancel: CoachingSession?
    @State private var sessionToDelete: CoachingSession?
    @State private var alertMessage: CoachingAlertMessage?

    /// A session only counts toward the monthly quota while it's still upcoming — otherwise a
    /// player who attended sessions weeks ago would stay blocked from booking new ones forever.
    private func isUpcoming(_ session: CoachingSession) -> Bool {
        (session.date ?? .distantPast) >= Date()
    }

    private var myUpcomingSessions: [CoachingSession] {
        sessions.filter { $0.player == player && isUpcoming($0) }
            .sorted { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }
    }

    /// Casual: 1 coaching session/month. Competitive: 3/month. Matches the membership plan —
    /// extra sessions beyond this require a paid add-on that isn't billed by the app yet.
    private func monthlyQuota(for player: Player) -> Int {
        AppConstants.isRanked(player.membership) ? 3 : 1
    }

    private func mySessionsInSameMonth(as date: Date?) -> [CoachingSession] {
        guard let date else { return [] }
        let calendar = Calendar.current
        return myUpcomingSessions.filter {
            guard let sessionDate = $0.date else { return false }
            return calendar.isDate(sessionDate, equalTo: date, toGranularity: .month)
        }
    }

    struct CoachingAlertMessage: Identifiable {
        let id = UUID()
        let message: String
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Label("Coaching Sessions", systemImage: "calendar")
                    .font(.title2)
                    .bold()
                    .padding(.top)

                if !AppConstants.isStaff(player.role) {
                    Text("Your monthly quota: \(monthlyQuota(for: player)) session\(monthlyQuota(for: player) == 1 ? "" : "s") (\(player.membership ?? "No membership"))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if !myUpcomingSessions.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Your Booked Sessions", systemImage: "checkmark.circle.fill")
                            .font(.headline)
                            .foregroundColor(.green)

                        ForEach(Array(myUpcomingSessions.enumerated()), id: \.element) { index, mySession in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(mySession.title ?? "Untitled")
                                Text("Coach: \(mySession.coachName ?? "Unknown")")
                                Text("Date: \(mySession.date?.formatted(date: .abbreviated, time: .shortened) ?? "TBD")")

                                Button("Cancel Booking", role: .destructive) {
                                    sessionToCancel = mySession
                                }
                            }
                            .padding(.vertical, 4)
                            if index < myUpcomingSessions.count - 1 {
                                Divider()
                            }
                        }
                    }
                    .padding()
                    .cardStyle()
                    .padding(.horizontal)
                }

                VStack(spacing: 12) {
                    ForEach(sessions) { session in
                        sessionRow(session)
                    }
                }
                .padding(.horizontal)

                if AppConstants.isStaff(player.role) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Label("Add Session", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.bordered)
                    .padding()
                }

                Spacer(minLength: 20)
            }
        }
        .background(Color("AppBackground").ignoresSafeArea())
        .sheet(isPresented: $showAddSheet) {
            AddSessionView()
        }
        .sheet(item: $sessionToEdit) { session in
            AddSessionView(sessionToEdit: session)
        }
        .alert(item: $alertMessage) { alert in
            Alert(title: Text("Notice"), message: Text(alert.message), dismissButton: .default(Text("OK")))
        }
        .confirmationDialog(
            "Cancel this booking?",
            isPresented: Binding(get: { sessionToCancel != nil }, set: { if !$0 { sessionToCancel = nil } }),
            titleVisibility: .visible
        ) {
            Button("Cancel Booking", role: .destructive) {
                if let sessionToCancel {
                    cancelBooking(sessionToCancel)
                }
                sessionToCancel = nil
            }
            Button("Keep Booking", role: .cancel) { sessionToCancel = nil }
        }
        .confirmationDialog(
            "Delete this session?",
            isPresented: Binding(get: { sessionToDelete != nil }, set: { if !$0 { sessionToDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete Session", role: .destructive) {
                if let sessionToDelete {
                    deleteSession(sessionToDelete)
                }
                sessionToDelete = nil
            }
            Button("Cancel", role: .cancel) { sessionToDelete = nil }
        }
        .navigationTitle("Coaching")
    }

    @ViewBuilder
    private func sessionRow(_ session: CoachingSession) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(session.title ?? "Untitled")
                    .font(.headline)
                Spacer()
                if AppConstants.isStaff(player.role) {
                    Button {
                        sessionToEdit = session
                    } label: {
                        Image(systemName: "pencil.circle.fill")
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Edit session")

                    Button {
                        sessionToDelete = session
                    } label: {
                        Image(systemName: "trash.circle.fill")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Delete session")
                }
            }
            Text("Coach: \(session.coachName ?? "Unknown")")
            Text("Date: \(session.date?.formatted(date: .abbreviated, time: .shortened) ?? "TBD")")

            if session.isBooked {
                if session.player == player {
                    Text("Booked by you")
                        .foregroundColor(.blue)
                } else {
                    Text("Booked")
                        .foregroundColor(.red)
                }
            } else if !isUpcoming(session) {
                Text("Session passed")
                    .foregroundColor(.gray)
            } else {
                if !AppConstants.isStaff(player.role) {
                    let quotaUsed = mySessionsInSameMonth(as: session.date).count >= monthlyQuota(for: player)
                    Button("Book Session") {
                        bookSession(session, quotaUsed: quotaUsed)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(quotaUsed)
                } else {
                    Text("Status: Open")
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func bookSession(_ session: CoachingSession, quotaUsed: Bool) {
        if quotaUsed {
            alertMessage = CoachingAlertMessage(message: "You've used all \(monthlyQuota(for: player)) coaching session(s) for this month.")
            return
        }
        session.player = player
        session.isBooked = true
        do {
            try viewContext.save()
            alertMessage = CoachingAlertMessage(message: "Session booked!")
        } catch {
            viewContext.rollback()
            alertMessage = CoachingAlertMessage(message: "Couldn't book: \(error.localizedDescription)")
        }
    }

    private func cancelBooking(_ session: CoachingSession) {
        session.isBooked = false
        session.player = nil
        do {
            try viewContext.save()
            alertMessage = CoachingAlertMessage(message: "Session canceled.")
        } catch {
            viewContext.rollback()
            alertMessage = CoachingAlertMessage(message: "Couldn't cancel: \(error.localizedDescription)")
        }
    }

    private func deleteSession(_ session: CoachingSession) {
        viewContext.delete(session)
        do {
            try viewContext.save()
        } catch {
            viewContext.rollback()
            alertMessage = CoachingAlertMessage(message: "Couldn't delete: \(error.localizedDescription)")
        }
    }
}
