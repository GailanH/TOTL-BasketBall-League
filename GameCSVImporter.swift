import Foundation
import CoreData

/// Staff batch upload of game results (Record Game → Choose CSV File), e.g. from a
/// statistician's sheet. One row per player per game:
///
/// `game, username, team, result, points, rebounds, assists, blocks, steals` and optionally `date`
///
/// - Rows sharing a `game` value are one game. `team` is A or B; `result` is W or L.
/// - `date` is `2026-10-21` or `2026-10-21 18:30`. Games are recorded oldest first so RP builds
///   up in the order they were played; undated games keep file order after now.
/// - Each game goes through `MatchRecorder`, exactly like a game entered by hand. A game with
///   any bad row is skipped whole; the other games are still recorded.
enum GameCSVImporter {

    static let requiredColumns = ["game", "username", "team", "result", "points", "rebounds", "assists", "blocks", "steals"]

    struct Result {
        var recorded = 0
        var errors: [String] = []

        var summary: String {
            var text = "\(recorded) game(s) recorded from CSV."
            if !errors.isEmpty {
                let shown = errors.prefix(10)
                text += " \(errors.count) problem(s):\n" + shown.joined(separator: "\n")
                if errors.count > shown.count { text += "\n…and \(errors.count - shown.count) more." }
            }
            return text
        }
    }

    private struct Row {
        let username: String
        let team: Team
        let won: Bool
        let stats: StatLine
        let date: Date?
    }

    /// Parses and records. Saves on success; on a save failure nothing is kept.
    static func importCSV(_ text: String, in context: NSManagedObjectContext, now: Date = Date()) -> Result {
        var result = Result()
        guard let table = CSVTable(text: text) else {
            result.errors.append("The file is empty.")
            return result
        }
        let missing = requiredColumns.filter { !table.headers.contains($0) }
        guard missing.isEmpty else {
            result.errors.append("CSV is missing required column(s): \(missing.joined(separator: ", ")).")
            return result
        }

        var gameOrder: [String] = []
        var rowsByGame: [String: [Row]] = [:]
        var badGames = Set<String>()

        for row in table.rows {
            func field(_ name: String) -> String? { table.value(name, in: row.fields) }
            let line = "Row \(row.line)"

            guard let gameKey = field("game"), !gameKey.isEmpty else {
                result.errors.append("\(line): missing game.")
                continue
            }
            if rowsByGame[gameKey] == nil { gameOrder.append(gameKey); rowsByGame[gameKey] = [] }

            guard let username = field("username"), !username.isEmpty,
                  let team = field("team").flatMap({ Team(rawValue: $0.uppercased()) }),
                  let outcome = field("result")?.uppercased(), outcome == "W" || outcome == "L",
                  let p = field("points").flatMap({ Int64($0) }),
                  let r = field("rebounds").flatMap({ Int64($0) }),
                  let a = field("assists").flatMap({ Int64($0) }),
                  let b = field("blocks").flatMap({ Int64($0) }),
                  let s = field("steals").flatMap({ Int64($0) })
            else {
                result.errors.append("\(line): needs a username, team A/B, result W/L, and whole-number stats.")
                badGames.insert(gameKey)
                continue
            }
            var date: Date? = nil
            if let dateText = field("date"), !dateText.isEmpty {
                guard let parsed = CSVTable.parseDate(dateText) else {
                    result.errors.append("\(line): date must look like 2026-10-21 or 2026-10-21 18:30.")
                    badGames.insert(gameKey)
                    continue
                }
                date = parsed
            }
            rowsByGame[gameKey]?.append(Row(username: username, team: team, won: outcome == "W",
                                            stats: StatLine(points: p, rebounds: r, assists: a, blocks: b, steals: s),
                                            date: date))
        }

        let gameDates: [String: Date] = Dictionary(uniqueKeysWithValues: gameOrder.enumerated().map { index, key in
            (key, rowsByGame[key]?.compactMap(\.date).first ?? now.addingTimeInterval(TimeInterval(index)))
        })
        let orderedGames = gameOrder.enumerated()
            .sorted { (gameDates[$0.element]!, $0.offset) < (gameDates[$1.element]!, $1.offset) }
            .map(\.element)

        for gameKey in orderedGames {
            guard !badGames.contains(gameKey) else {
                result.errors.append("Game \(gameKey): skipped because of the row error(s) above.")
                continue
            }
            let rows = rowsByGame[gameKey] ?? []
            let winners = Set(rows.filter(\.won).map(\.team))
            let losers = Set(rows.filter { !$0.won }.map(\.team))
            guard winners.count == 1, let winner = winners.first, !losers.contains(winner) else {
                result.errors.append("Game \(gameKey): exactly one team must be W and the other L.")
                continue
            }

            var entries: [MatchEntry] = []
            var missingPlayer: String?
            for row in rows {
                let request: NSFetchRequest<Player> = Player.fetchRequest()
                request.predicate = NSPredicate(format: "username ==[c] %@", row.username)
                request.fetchLimit = 1
                guard let player = try? context.fetch(request).first else { missingPlayer = row.username; break }
                entries.append(MatchEntry(player: player, team: row.team, stats: row.stats))
            }
            if let missingPlayer {
                result.errors.append("Game \(gameKey): no player found with username '\(missingPlayer)'.")
                continue
            }

            do {
                try MatchRecorder.record(entries, winner: winner, date: gameDates[gameKey] ?? now, in: context)
                result.recorded += 1
            } catch {
                result.errors.append("Game \(gameKey): \(error.localizedDescription)")
            }
        }

        if result.recorded > 0 {
            do {
                try context.save()
            } catch {
                context.rollback()
                result.errors.append("Save failed: \(error.localizedDescription)")
                result.recorded = 0
            }
        }
        return result
    }
}
