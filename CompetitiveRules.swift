import Foundation

/// Every tunable number in the competitive system, in one place. Change a rule here and the
/// app, CSV import, edits, and tests all follow. Values are starting points (D1–D4 decided
/// 2026-10-18; rebalanced against RP inflation 2026-10-21, see ROADMAP.md D8) and are expected
/// to be tuned with pilot-league data.
///
/// Balance target: a player already at their true rank who wins half their games should hold
/// roughly steady over a season. Simulated drift with these values: about +0.3 RP per game
/// (was +5.6 before the rebalance, i.e. more than a tier and a half of free climbing a season).
enum CompetitiveRules {

    // MARK: Per-stat scoring (a stat line vs. the player's tier averages)

    /// RP earned per unit a stat is above the tier average.
    static let gainPerStatUnit: Int64 = 2
    /// RP lost per unit a stat is below the tier average. Same as the gain, so an average
    /// game scores about zero.
    static let lossPerStatUnit: Int64 = 2
    /// Most RP a single stat can add, so one huge stat can't max out a whole game.
    static let perStatGainCap: Int64 = 15
    /// Most RP a single stat can cost.
    static let perStatLossCap: Int64 = 15

    // MARK: Per-game limits

    /// Range a game's stat score is clamped to before it's applied (see `RankSystem.baseRP`).
    static let gameGainCap: Int64 = 50
    static let gameLossCap: Int64 = 20
    /// Most RP any one game can cost overall (before the placement multiplier).
    static let maxGameLoss: Int64 = 30

    // MARK: Win / loss (D4, rebalanced 2026-10-21)
    //
    // The result drives the change; the stat score adjusts it. A game's change is:
    //   winner:  winBonus + stat score / performanceDivisor, at least winnerMinimumGain (+ mvpBonus)
    //   SVP:     -svpLossPenalty + stat score / divisor, at most svpMaxGain
    //   loser:   -lossPenalty + stat score / divisor, at most 0
    // Typical results: win +10, MVP +20, loss -17, SVP -4 (a great SVP game can reach +5).

    /// Base RP for winning.
    static let winBonus: Int64 = 10
    /// Every player on the winning team earns at least this much.
    static let winnerMinimumGain: Int64 = 3
    /// Extra RP for the winning team's best performer.
    static let mvpBonus: Int64 = 5
    /// Base RP lost for losing. A bit larger than `winBonus` because three winners (plus the MVP
    /// bonus) gain while only two full losers and a half-penalty SVP lose.
    static let lossPenalty: Int64 = 15
    /// The losing team's best performer (SVP) loses half as much as their teammates.
    static let svpLossPenalty: Int64 = 7
    /// A great SVP game can still earn a little, at most this much. Other losers never gain.
    static let svpMaxGain: Int64 = 5
    /// The stat score counts 1/divisor toward the change, so the result matters most.
    static let performanceDivisor: Int64 = 2

    // MARK: Underdog win (decided 2026-10-21)

    /// Extra RP for each winner when the whole winning team is at least one full metal below
    /// the whole losing team: every winner's metal (Bronze, Silver, Gold...) is lower than every
    /// loser's. 3 Silvers beating 3 Golds qualifies; 2 Silvers + 1 Gold beating 3 Golds doesn't.
    static let underdogWinBonus: Int64 = 5

    // MARK: Seasons and placement (D3)

    static let seasonLengthMonths = 3
    /// Placement games each player plays at the start of every season (and when new).
    static let placementGames: Int16 = 5
    /// RP swings are multiplied by this during placement so players find their level fast.
    static let placementMultiplier: Int64 = 2
    /// Soft reset: at season end a player drops this many tiers, to the bottom of that tier.
    static let softResetTierDrop = 3
}
