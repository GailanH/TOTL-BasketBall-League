import Foundation

/// Shared sanity bounds for a single game's stat line — rejects obvious garbage or typos
/// (an extra digit, a negative number) without being overly restrictive on real performances.
/// Used by the manual Add Game form, the CSV batch importer, and game editing, so a bad row
/// can't sneak in through one path but not another.
enum GameStatBounds {
    static let maxPoints: Int64 = 150
    static let maxRebounds: Int64 = 60
    static let maxAssists: Int64 = 60
    static let maxBlocks: Int64 = 40
    static let maxSteals: Int64 = 40

    /// A human-readable error if any stat is out of bounds, else nil.
    static func validate(points: Int64, rebounds: Int64, assists: Int64, blocks: Int64, steals: Int64) -> String? {
        if points < 0 || rebounds < 0 || assists < 0 || blocks < 0 || steals < 0 {
            return "Stats can't be negative."
        }
        if points > maxPoints { return "Points can't exceed \(maxPoints) in a single game." }
        if rebounds > maxRebounds { return "Rebounds can't exceed \(maxRebounds) in a single game." }
        if assists > maxAssists { return "Assists can't exceed \(maxAssists) in a single game." }
        if blocks > maxBlocks { return "Blocks can't exceed \(maxBlocks) in a single game." }
        if steals > maxSteals { return "Steals can't exceed \(maxSteals) in a single game." }
        return nil
    }
}
