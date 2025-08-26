import Foundation
import CoreData

enum DashboardRoute: Hashable {
    case coaching
    case editAccounts
    case overview
    case playerOverview
    case addGame
    case leaderboard
    case editProfile(playerID: NSManagedObjectID)
    case rankTimeline(player: Player)
}
