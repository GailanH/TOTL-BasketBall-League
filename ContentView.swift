import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var loggedInPlayer: Player?
    @State private var didAttemptRestore = false

    var body: some View {
        Group {
            if let player = loggedInPlayer {
                DashboardView(playerID: player.objectID, loggedInPlayer: $loggedInPlayer)
            } else {
                LoginView(loggedInPlayer: $loggedInPlayer)
            }
        }
        .onAppear {
            guard !didAttemptRestore else { return }
            didAttemptRestore = true
            if DemoData.isUITesting {
                SessionStore.save(nil)
            }
            DemoData.seedIfRequested(in: viewContext)
            loggedInPlayer = DemoData.loginPlayer(in: viewContext) ?? SessionStore.restore(in: viewContext)
        }
        .onChange(of: loggedInPlayer) { newValue in
            SessionStore.save(newValue)
        }
    }
}
