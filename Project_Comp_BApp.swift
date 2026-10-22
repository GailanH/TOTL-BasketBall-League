
import SwiftUI

@main
struct Project_Comp_BApp: App {
    let persistenceController = PersistenceController.shared
    let gameNightStore: GameNightStore = CoreDataGameNightStore(
        context: PersistenceController.shared.container.viewContext
    )

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environment(\.gameNightStore, gameNightStore)
        }
    }
}
