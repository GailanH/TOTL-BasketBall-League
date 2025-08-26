import SwiftUI

struct ContentView: View {
    @AppStorage("isFirstLaunch") private var isFirstLaunch: Bool = true
    @State private var loggedInPlayer: Player?

    var body: some View {
        if let player = loggedInPlayer {
            DashboardView(playerID: player.objectID, loggedInPlayer: $loggedInPlayer)
        } else {
            LoginView(loggedInPlayer: $loggedInPlayer)
        }
    }
}
