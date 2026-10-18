import CoreData

/// Persists which player is logged in across app launches, so users aren't forced to
/// re-enter their username and password every time they open the app.
enum SessionStore {
    private static let key = "loggedInPlayerURIString"

    static func save(_ player: Player?) {
        guard let player, !player.isDeleted else {
            UserDefaults.standard.removeObject(forKey: key)
            return
        }
        UserDefaults.standard.set(player.objectID.uriRepresentation().absoluteString, forKey: key)
    }

    static func restore(in context: NSManagedObjectContext) -> Player? {
        guard let uriString = UserDefaults.standard.string(forKey: key),
              let uri = URL(string: uriString),
              let coordinator = context.persistentStoreCoordinator,
              let objectID = coordinator.managedObjectID(forURIRepresentation: uri),
              let object = try? context.existingObject(with: objectID)
        else { return nil }

        return object as? Player
    }
}
