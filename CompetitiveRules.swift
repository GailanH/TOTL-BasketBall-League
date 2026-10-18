import Foundation

/// Every tunable number in the competitive system, in one place. Change a rule here and the
/// app, CSV import, edits, and tests all follow. Values are starting points (decided
/// 2026-10-18, see ROADMAP.md D1–D4) and are expected to be tuned with pilot-league data.
enum CompetitiveRules {

    // MARK: Per-stat scoring (a stat line vs. the player's tier averages)

    /// RP earned per unit a stat is above the tier average.
    static let gainPerStatUnit: Int64 = 2
    /// RP lost per unit a stat is below the tier average.
    static let lossPerStatUnit: Int64 = 1
    /// Most RP a single stat can add, so one huge stat can't max out a whole game.
    static let perStatGainCap: Int64 = 15
    /// Most RP a single stat can cost.
    static let perStatLossCap: Int64 = 10

    // MARK: Per-game limits

    /// Most RP any one game can earn (before the placement multiplier).
    static let gameGainCap: Int64 = 50
    /// Most RP any one game can cost (before the placement multiplier).
    static let gameLossCap: Int64 = 20

    // MARK: Win / loss (D4)

    /// Every player on the winning team earns at least this much.
    static let winnerMinimumGain: Int64 = 5
    /// Extra RP for the winning team's best performer.
    static let mvpBonus: Int64 = 10
    /// The losing team's best performer (SVP) can earn at most this much. Everyone else on the
    /// losing team can only lose RP or break even. If the SVP also played below average, they
    /// lose RP like their teammates.
    static let svpMaxGain: Int64 = 5

    // MARK: Seasons and placement (D3)

    static let seasonLengthMonths = 3
    /// Placement games each player plays at the start of every season (and when new).
    static let placementGames: Int16 = 5
    /// RP swings are multiplied by this during placement so players find their level fast.
    static let placementMultiplier: Int64 = 2
    /// Soft reset: at season end a player drops this many tiers, to the bottom of that tier.
    static let softResetTierDrop = 3
}
