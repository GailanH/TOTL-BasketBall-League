#if DEBUG
import Foundation
import CoreData

/// TEST TOOL, Debug builds only: long-lived dummy game nights for checking how the app looks
/// with a full schedule. They're dated in 2030 so they never drift into the past, and they
/// use their own test venues. Adding them twice does nothing. RSVPs reuse whatever Competitive
/// members already exist (no accounts are created); with none, the nights simply show open
/// spots. See DebugTools/README.md.
enum TestGameNights {

    /// Every test night's notes start with this, so a second run can tell they're already there.
    static let marker = "[Test night]"
    static let year = 2030

    /// (month, day, venue index, capacity, how many RSVPs, notes)
    /// Jan 1 2030 is a Tuesday, so these are all Tuesdays and Thursdays.
    private static let plan: [(Int, Int, Int, Int16, Int, String)] = [
        (1, 8, 0, 10, 13, "Full with a waitlist of 3."),
        (1, 10, 1, 18, 16, "Almost full: 2 spots left."),
        (1, 15, 0, 20, 10, "Half full."),
        (1, 17, 1, 36, 0, "Nobody's RSVP'd yet."),
        (1, 22, 0, 16, 6, "Long note test: bring a light and a dark shirt, park in the side lot, the east doors open at 6:30, and water is available inside, but bring your own bottle."),
        (1, 24, 1, 12, 12, "Exactly full, no waitlist."),
        (1, 29, 0, 20, 4, ""),
        (1, 31, 1, 30, 15, "")
    ]

    static func add(in context: NSManagedObjectContext) -> (title: String, message: String) {
        let store = CoreDataGameNightStore(context: context)
        do {
            let existing = try store.allGameNights().filter { $0.notes.hasPrefix(marker) }
            if !existing.isEmpty {
                return ("Already Added", "The \(existing.count) test game nights (January \(year)) are already in the app.")
            }

            let venues = [
                VenueRecord(name: "Test Gym A (test data)", address: "100 Military Plaza, San Antonio, TX 78205",
                            courtCount: 2, notes: "Test data."),
                VenueRecord(name: "Test Gym B (test data)", address: "300 Alamo Plaza, San Antonio, TX 78205",
                            courtCount: 4, notes: "Test data.")
            ]
            for venue in venues { try store.saveVenue(venue) }

            let members = competitiveUsernames(in: context)
            let calendar = LeagueSettings.calendar
            var rsvpTime = Date().addingTimeInterval(-3600)

            for (month, day, venueIndex, capacity, rsvps, notes) in plan {
                guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else { continue }
                var night = GameNightRecord.newNight(on: date, at: venues[venueIndex])
                night.capacity = capacity
                night.courtsInUse = venues[venueIndex].courtCount
                night.notes = notes.isEmpty ? marker : "\(marker) \(notes)"
                try store.saveGameNight(night, createdBy: nil)
                for username in members.prefix(rsvps) {
                    rsvpTime += 1
                    try? store.rsvp(nightID: night.id, username: username, now: rsvpTime)
                }
            }

            let note = members.isEmpty
                ? " There are no Competitive members yet, so every night shows open spots. Load the sample league first to fill them."
                : ""
            return ("Test Game Nights Added",
                    "\(plan.count) game nights in January \(year) at 2 test venues, from empty to full with a waitlist.\(note)")
        } catch {
            return ("Couldn't Add Test Nights", error.localizedDescription)
        }
    }

    private static func competitiveUsernames(in context: NSManagedObjectContext) -> [String] {
        let request: NSFetchRequest<Player> = Player.fetchRequest()
        request.predicate = NSPredicate(format: "membership == %@", AppConstants.competitiveMembership)
        request.sortDescriptors = [NSSortDescriptor(key: "username", ascending: true)]
        return ((try? context.fetch(request)) ?? []).compactMap(\.username)
    }
}
#endif
