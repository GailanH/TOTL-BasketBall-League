import Foundation

enum Team: String, CaseIterable, Identifiable {
    case a = "A"
    case b = "B"
    var id: String { rawValue }
    var displayName: String { "Team \(rawValue)" }
}

enum Award: String {
    /// Most valuable player: the winning team's best performer.
    case mvp = "MVP"
    /// Second valuable player: the losing team's best performer.
    case svp = "SVP"
}

/// Pure win/loss scoring for one game (D4). No Core Data, so it's fully unit-testable.
///
/// Rules (numbers and formulas in `CompetitiveRules`):
/// - Each player's stat score is their stat line vs. their own tier's averages (`RankSystem.baseRP`).
/// - Winners gain the win bonus plus part of their stat score, never less than the minimum; the
///   MVP gets a bonus on top.
/// - Losers lose the loss penalty, softened by a good stat score but never turning into a gain.
///   The SVP loses half as much, and a great SVP game can still earn a little.
/// - Underdog win: if every winner is in a lower metal than every loser, each winner gets
///   `underdogWinBonus` on top.
/// - Placement games multiply the final result by `placementMultiplier`.
/// - MVP/SVP go to the best `performanceScore` on each team. Ties go to more points, then to
///   whoever is listed first.
enum MatchScoring {

    struct Participant {
        let team: Team
        let stats: StatLine
        /// The player's rank going into this game.
        let rank: String
        let isPlacement: Bool
    }

    struct Outcome: Equatable {
        let won: Bool
        let award: Award?
        let performance: Int64
        /// RP change before the 0-RP floor is applied (the recorder applies the floor).
        let rpChange: Int64
        /// True for winners of an underdog win (their change includes `underdogWinBonus`).
        var underdogBonus = false
    }

    /// True if every winner is in a lower metal than every loser (see `underdogWinBonus`).
    static func isUnderdogWin(_ participants: [Participant], winner: Team) -> Bool {
        let winnerMetals = participants.filter { $0.team == winner }.compactMap { RankSystem.metal(of: $0.rank) }
        let loserMetals = participants.filter { $0.team != winner }.compactMap { RankSystem.metal(of: $0.rank) }
        guard let highestWinner = winnerMetals.max(), let lowestLoser = loserMetals.min() else { return false }
        return highestWinner < lowestLoser
    }

    /// A human-readable problem with the line-up, or `nil` if it can be scored.
    static func validate(_ participants: [Participant]) -> String? {
        for team in Team.allCases where !participants.contains(where: { $0.team == team }) {
            return "\(team.displayName) needs at least one player."
        }
        return nil
    }

    /// Outcomes in the same order as `participants`. Call `validate` first. With an invalid
    /// line-up this still returns outcomes, but no award goes to an empty team.
    static func score(_ participants: [Participant], winner: Team) -> [Outcome] {
        let performances = participants.map { RankSystem.performanceScore($0.stats, at: $0.rank) }

        func bestIndex(on team: Team) -> Int? {
            participants.indices
                .filter { participants[$0].team == team }
                .max { lhs, rhs in
                    // Full tie: the earlier-listed player ranks higher.
                    if performances[lhs] != performances[rhs] { return performances[lhs] < performances[rhs] }
                    if participants[lhs].stats.points != participants[rhs].stats.points {
                        return participants[lhs].stats.points < participants[rhs].stats.points
                    }
                    return lhs > rhs
                }
        }

        let loser: Team = (winner == .a) ? .b : .a
        let mvpIndex = bestIndex(on: winner)
        let svpIndex = bestIndex(on: loser)
        let underdog = isUnderdogWin(participants, winner: winner)

        return participants.indices.map { i in
            let p = participants[i]
            let base = RankSystem.baseRP(p.stats, at: p.rank)
            let won = p.team == winner
            var award: Award? = nil
            var change: Int64

            // Swift's `/` truncates toward zero, so -15 / 2 == -7.
            let statPart = base / CompetitiveRules.performanceDivisor

            if won {
                change = max(CompetitiveRules.winBonus + statPart, CompetitiveRules.winnerMinimumGain)
                if i == mvpIndex {
                    award = .mvp
                    change += CompetitiveRules.mvpBonus
                }
                if underdog {
                    change += CompetitiveRules.underdogWinBonus
                }
                change = min(change, CompetitiveRules.gameGainCap)
            } else if i == svpIndex {
                award = .svp
                change = min(-CompetitiveRules.svpLossPenalty + statPart, CompetitiveRules.svpMaxGain)
            } else {
                change = min(-CompetitiveRules.lossPenalty + statPart, 0)
            }
            change = max(change, -CompetitiveRules.maxGameLoss)

            if p.isPlacement {
                change *= CompetitiveRules.placementMultiplier
            }

            return Outcome(won: won, award: award, performance: performances[i], rpChange: change,
                           underdogBonus: won && underdog)
        }
    }
}
