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
    case upcomingGameNights
    case gameNight(id: UUID)
    case manageGameNights
    case roster(nightID: UUID)
    case recordGame(GamePrefill)
    case venues
    case editProfile(playerID: NSManagedObjectID)
    case rankTimeline(player: Player)
    case seasonTimeline(player: Player, season: Season)
    case seasonHistory(player: Player)
    case pastSeasons
    case seasonStandings(season: Season)
}
