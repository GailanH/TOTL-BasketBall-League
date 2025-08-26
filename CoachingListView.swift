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
    @State private var alertMessage: CoachingAlertMessage?

    
    struct CoachingAlertMessage: Identifiable {
        let id = UUID()
        let message: String
    }


    var body: some View {
        VStack {
            Text("📅 Coaching Sessions")
                .font(.title2)
                .bold()
                .padding(.top)

            if let mySession = sessions.first(where: { $0.player == player }) {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("✅ Your Booked Session")
                            .font(.headline)

                        Text(mySession.title ?? "Untitled")
                        Text("Coach: \(mySession.coachName ?? "Unknown")")
                        Text("Date: \(mySession.date?.formatted(date: .abbreviated, time: .shortened) ?? "TBD")")

                        Button("Cancel Booking", role: .destructive) {
                            mySession.isBooked = false
                            mySession.player = nil
                            try? viewContext.save()
                            alertMessage = CoachingAlertMessage(message: "Session canceled.")
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal)
                }
            }

            List {
                ForEach(sessions) { session in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(session.title ?? "Untitled")
                            .font(.headline)
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
                        } else {
                            if player.role == "player" {
                                Button("Book Session") {
                                    // Only book if no other session is booked
                                    if sessions.contains(where: { $0.player == player }) {
                                        alertMessage = CoachingAlertMessage(message: "You already have a session booked.")
                                    } else {
                                        session.player = player
                                        session.isBooked = true
                                        try? viewContext.save()
                                        alertMessage = CoachingAlertMessage(message: "✅ Session booked!")
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(sessions.contains(where: { $0.player == player }))
                            } else {
                                Text("Status: Open")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onDelete { indexSet in
                    guard player.role == "employee" else { return }
                    for index in indexSet {
                        viewContext.delete(sessions[index])
                    }
                    try? viewContext.save()
                }
            }
            .listStyle(.plain)

            if player.role == "employee" {
                Button("➕ Add Session") {
                    showAddSheet = true
                }
                .buttonStyle(.bordered)
                .padding()
            }
        }
        .padding(.top)
        .sheet(isPresented: $showAddSheet) {
            AddSessionView()
        }
        .alert(item: $alertMessage) { alert in
            Alert(title: Text("Notice"), message: Text(alert.message), dismissButton: .default(Text("OK")))
        }
        .navigationTitle("Coaching")
    }
}

