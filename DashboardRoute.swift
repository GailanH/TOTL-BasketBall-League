import Foundation
import CoreData

enum DashboardRoute: Hashable {
    case coaching
    case editAccounts
    case pendingApprovals
    case overview
    case playerOverview
    case addGame
    case leaderboard
    case seasons
    case editProfile(playerID: NSManagedObjectID)
    case rankTimeline(player: Player)
}
