import Foundation
import CoreData

/// Launch-argument switches for UI tests and demos. Debug builds only, so a shipped app can
/// never be started pre-logged-in or with fake data.
///
/// - `-uiTesting`: use a fresh in-memory database and forget any saved login.
/// - `-seedDemoData`: fill the database with a staff account, Competitive players across
///   several ranks, a Casual member, and an active Season 1.
/// - `-loginAs <username>`: start already logged in as that user.
enum DemoData {

    static let staffUsername = "coach_demo"
    static let password = "demo-pass-123"

    /// Competitive demo players: (username, starting RP, placement games left).
    static let players: [(String, Int64, Int16)] = [
        ("jordan_g", 480, 0),  // Gold II
        ("maya_r", 360, 0),    // Silver I
        ("dre_w", 260, 0),     // Silver III
        ("sam_k", 180, 0),     // Bronze II
        ("lee_t", 60, 0),      // Rookie
        ("newbie_p", 0, 5)     // still in placement
    ]
    static let casualUsername = "casual_cass"

    #if DEBUG
    static var arguments: [String] { ProcessInfo.processInfo.arguments }
    static var isUITesting: Bool { arguments.contains("-uiTesting") }
    static var shouldSeed: Bool { arguments.contains("-seedDemoData") }
    static var loginUsername: String? {
        guard let index = arguments.firstIndex(of: "-loginAs"), index + 1 < arguments.count else { return nil }
        return arguments[index + 1]
    }
    #else
    static let isUITesting = false
    static let shouldSeed = false
    static let loginUsername: String? = nil
    #endif

    /// Seeds the demo league if requested and the database is empty. Saves.
    static func seedIfRequested(in context: NSManagedObjectContext) {
        guard shouldSeed else { return }
        let request: NSFetchRequest<Player> = Player.fetchRequest()
        guard ((try? context.count(for: request)) ?? 0) == 0 else { return }

        SeasonManager.ensureActiveSeason(in: context)
        makePlayer(staffUsername, role: AppConstants.employeeRole, membership: AppConstants.competitiveMembership,
                   rp: 0, placement: 0, in: context)
        for (name, rp, placement) in players {
            makePlayer(name, role: AppConstants.playerRole, membership: AppConstants.competitiveMembership,
                       rp: rp, placement: placement, in: context)
        }
        makePlayer(casualUsername, role: AppConstants.playerRole, membership: AppConstants.casualMembership,
                   rp: 0, placement: 0, in: context)
        try? context.save()
    }

    /// The player to start logged in as, if `-loginAs` was passed and that user exists.
    static func loginPlayer(in context: NSManagedObjectContext) -> Player? {
        guard let username = loginUsername else { return nil }
        let request: NSFetchRequest<Player> = Player.fetchRequest()
        request.predicate = NSPredicate(format: "username ==[c] %@", username)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    @discardableResult
    private static func makePlayer(_ username: String, role: String, membership: String, rp: Int64,
                                   placement: Int16, in context: NSManagedObjectContext) -> Player {
        let salt = PasswordHasher.generateSalt()
        let player = Player(context: context)
        player.username = username
        player.email = "\(username)@demo.totl"
        player.password = PasswordHasher.hash(password: password, salt: salt)
        player.passwordSalt = salt
        player.role = role
        player.membership = membership
        player.rankPoints = rp
        player.placementGamesRemaining = placement
        player.lastRank = RankSystem.rankName(for: rp)
        return player
    }
}
