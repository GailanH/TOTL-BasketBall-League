import Foundation
import CoreData

/// TEST TOOL, Debug builds only. Bulk-creates test accounts from a CSV so the leaderboard
/// and rank timeline can be tried with a realistic league. Real members always create their
/// own account and password through sign-up; nothing in the app depends on this file.
/// To remove: delete the DebugTools folder and the `#if DEBUG` blocks marked "DebugTools"
/// (see DebugTools/README.md).
///
/// Columns (header row required, any order):
/// - `username`, `email`: required, same rules as sign-up.
/// - `membership`: `Competitive`, `Casual`, or blank for none.
/// - `password`: required, so the test account can log in.
/// - `rank_points`: optional, Competitive only. Starts the member at that RP as already placed
///   (for players moving over from another league or test data). Without it they start at
///   Rookie with the normal placement games.
/// - `joined`: optional date (`2026-09-01`), used as the start of the member's rank history.
///
/// Imported members are always players; staff accounts still go through sign-up and approval.
/// Rows with problems are skipped and reported; the rest are imported.
#if DEBUG
enum TestMemberImporter {

    static let requiredColumns = ["username", "email", "membership", "password"]

    struct Result {
        var imported: [String] = []
        var errors: [String] = []

        var summary: String {
            var text = "\(imported.count) test account(s) created."
            if !errors.isEmpty {
                let shown = errors.prefix(10)
                text += "\n\(errors.count) row(s) skipped:\n" + shown.joined(separator: "\n")
                if errors.count > shown.count { text += "\n…and \(errors.count - shown.count) more." }
            }
            return text
        }
    }

    /// Parses and imports. Saves on success; on a save failure nothing is kept.
    static func importCSV(_ text: String, in context: NSManagedObjectContext) -> Result {
        var result = Result()
        guard let table = CSVTable(text: text) else {
            result.errors.append("The file is empty.")
            return result
        }
        let missing = requiredColumns.filter { !table.headers.contains($0) }
        guard missing.isEmpty else {
            result.errors.append("Missing required column(s): \(missing.joined(separator: ", ")).")
            return result
        }

        var takenUsernames = Set<String>()
        var takenEmails = Set<String>()
        let existing = (try? context.fetch(Player.fetchRequest() as NSFetchRequest<Player>)) ?? []
        for player in existing {
            if let name = player.username { takenUsernames.insert(name.lowercased()) }
            if let email = player.email { takenEmails.insert(email.lowercased()) }
        }

        for row in table.rows {
            let line = "Row \(row.line)"
            let username = table.value("username", in: row.fields) ?? ""
            let email = table.value("email", in: row.fields) ?? ""
            let membershipText = table.value("membership", in: row.fields) ?? ""
            let password = table.value("password", in: row.fields) ?? ""
            let rankPointsText = table.value("rank_points", in: row.fields) ?? ""
            let joinedText = table.value("joined", in: row.fields) ?? ""

            guard AccountValidation.isValidUsername(username) else {
                result.errors.append("\(line): \(username.isEmpty ? "missing username" : "'\(username)': \(AccountValidation.usernameRule)")")
                continue
            }
            guard AccountValidation.isValidEmail(email) else {
                result.errors.append("\(line): '\(username)' needs a valid email.")
                continue
            }
            guard !takenUsernames.contains(username.lowercased()) else {
                result.errors.append("\(line): username '\(username)' is already taken.")
                continue
            }
            guard !takenEmails.contains(email.lowercased()) else {
                result.errors.append("\(line): email '\(email)' is already in use.")
                continue
            }

            let membership: String?
            switch membershipText.lowercased() {
            case "competitive": membership = AppConstants.competitiveMembership
            case "casual": membership = AppConstants.casualMembership
            case "", "none": membership = nil
            default:
                result.errors.append("\(line): membership must be Competitive, Casual, or blank (got '\(membershipText)').")
                continue
            }

            if !AccountValidation.isValidPassword(password) {
                result.errors.append("\(line): '\(username)': \(AccountValidation.passwordRule)")
                continue
            }

            var startingRP: Int64? = nil
            if !rankPointsText.isEmpty {
                guard let rp = Int64(rankPointsText), rp >= 0 else {
                    result.errors.append("\(line): rank_points must be a whole number, 0 or more.")
                    continue
                }
                guard membership == AppConstants.competitiveMembership else {
                    result.errors.append("\(line): rank_points only applies to Competitive members.")
                    continue
                }
                startingRP = rp
            }

            var joined = Date()
            if !joinedText.isEmpty {
                guard let parsed = CSVTable.parseDate(joinedText) else {
                    result.errors.append("\(line): joined must look like 2026-09-01.")
                    continue
                }
                joined = parsed
            }

            let salt = PasswordHasher.generateSalt()
            let player = Player(context: context)
            player.username = username
            player.email = email
            player.passwordSalt = salt
            player.password = PasswordHasher.hash(password: password, salt: salt)
            player.role = AppConstants.playerRole
            player.membership = membership
            player.rankPoints = startingRP ?? 0
            player.placementGamesRemaining = startingRP == nil ? CompetitiveRules.placementGames : 0

            let rank = RankSystem.rankName(for: player.rankPoints)
            player.lastRank = rank
            let change = RankChange(context: context)
            change.id = UUID()
            change.date = joined
            change.newRank = rank
            change.player = player
            change.season = SeasonManager.activeSeason(in: context)

            takenUsernames.insert(username.lowercased())
            takenEmails.insert(email.lowercased())
            result.imported.append(username)
        }

        if !result.imported.isEmpty {
            do {
                try context.save()
            } catch {
                context.rollback()
                result.errors.append("Save failed: \(error.localizedDescription)")
                result.imported = []
            }
        }
        return result
    }
}
#endif
