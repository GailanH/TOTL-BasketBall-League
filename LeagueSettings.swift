import Foundation

/// League operations settings (game nights, RSVPs, reminders), separate from the scoring rules
/// in `CompetitiveRules`. Views read these; they never hard-code them.
enum LeagueSettings {

    /// Game nights are shown in the venue's local time. All TOTL venues are in San Antonio.
    /// Dates are stored in UTC (`Date` is absolute) and only converted for display and entry.
    static let timeZone = TimeZone(identifier: "America/Chicago")!

    // MARK: Game night defaults (staff can change them per night)

    static let defaultCapacity: Int16 = 20
    static let defaultDuration: TimeInterval = 2 * 60 * 60
    static let defaultStartHour = 19  // 7 PM local
    static let defaultCourtsInUse: Int16 = 1

    /// Sanity bounds for the staff editor.
    static let capacityRange: ClosedRange<Int16> = 2...200
    static let maxDuration: TimeInterval = 8 * 60 * 60

    /// How many upcoming nights the dashboard previews.
    static let dashboardUpcomingCount = 3
    /// Cancelled nights stay visible to players this long before start, so nobody shows up to a
    /// cancelled night; after that they drop off the Upcoming list.
    static let showCancelledWithin: TimeInterval = 7 * 24 * 60 * 60

    /// A Calendar for building and formatting dates in league time.
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }
}
