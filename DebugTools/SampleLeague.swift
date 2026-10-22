#if DEBUG
import Foundation
import CoreData

/// TEST TOOL, Debug builds only. A ready-made league for trying the leaderboard and rank
/// timeline: 16 Competitive players (Rookie to Elite, two still in placement), 2 Casual
/// members, and 18 three-on-three games from Sep 7 to Oct 18 that produce promotions and
/// finish both placements. Every test account's password is `totl-demo-123`.
///
/// Loaded with "Load Sample League" on Edit Player Accounts. The players are created directly
/// (test accounts only; real members always sign up). The games go through the real
/// GameCSVImporter and MatchRecorder, so they're scored exactly like real games.
enum SampleLeague {

    struct LoadResult {
        let title: String
        let message: String
    }

    static func load(in context: NSManagedObjectContext) -> LoadResult {
        let request: NSFetchRequest<Player> = Player.fetchRequest()
        request.predicate = NSPredicate(format: "username ==[c] %@", "marcus_j")
        if ((try? context.count(for: request)) ?? 0) > 0 {
            return LoadResult(title: "Already Loaded", message: "The sample league is already in this app. Delete the app from the Simulator to start fresh.")
        }

        for (username, membership, startingRP) in members {
            addPlayer(username, membership: membership, startingRP: startingRP, in: context)
        }
        do {
            try context.save()
        } catch {
            context.rollback()
            return LoadResult(title: "Nothing Loaded", message: "Couldn't save the sample players: \(error.localizedDescription)")
        }
        let games = GameCSVImporter.importCSV(gamesCSV, in: context)
        return LoadResult(
            title: "Sample League Loaded",
            message: "\(members.count) test players added.\n\(games.summary)\n\nTest accounts use the password \(password)."
        )
    }

    /// (username, membership, starting RP). Competitive players with a starting RP count as
    /// already placed; `nil` means a new player who still has placement games.
    static let members: [(String, String, Int64?)] = [
        ("marcus_j", "Competitive", 720),
        ("tasha_b", "Competitive", 640),
        ("dev_o", "Competitive", 585),
        ("kev_m", "Competitive", 530),
        ("rico_s", "Competitive", 470),
        ("jaylen_w", "Competitive", 430),
        ("bree_c", "Competitive", 380),
        ("omar_h", "Competitive", 330),
        ("nina_p", "Competitive", 290),
        ("tyler_r", "Competitive", 240),
        ("zoe_k", "Competitive", 190),
        ("andre_l", "Competitive", 140),
        ("mia_f", "Competitive", 90),
        ("luis_g", "Competitive", 40),
        ("rookie_ray", "Competitive", nil),
        ("rookie_jen", "Competitive", nil),
        ("casual_cam", "Casual", nil),
        ("casual_dana", "Casual", nil)
    ]

    static let password = "totl-demo-123"
    static let joined = CSVTable.parseDate("2026-09-01")!

    private static func addPlayer(_ username: String, membership: String, startingRP: Int64?,
                                  in context: NSManagedObjectContext) {
        let salt = PasswordHasher.generateSalt()
        let player = Player(context: context)
        player.username = username
        player.email = "\(username)@example.com"
        player.passwordSalt = salt
        player.password = PasswordHasher.hash(password: password, salt: salt)
        player.role = AppConstants.playerRole
        player.membership = membership
        player.rankPoints = startingRP ?? 0
        player.placementGamesRemaining = startingRP == nil && membership == AppConstants.competitiveMembership
            ? CompetitiveRules.placementGames : 0
        let rank = RankSystem.rankName(for: player.rankPoints)
        player.lastRank = rank
        let change = RankChange(context: context)
        change.id = UUID()
        change.date = joined
        change.newRank = rank
        change.player = player
    }

    static let gamesCSV = """
game,date,username,team,result,points,rebounds,assists,blocks,steals
G01,2026-09-07 19:00,jaylen_w,A,W,11,5,3,1,1
G01,2026-09-07 19:00,nina_p,A,W,8,5,2,0,1
G01,2026-09-07 19:00,bree_c,A,W,14,6,5,0,4
G01,2026-09-07 19:00,zoe_k,B,L,6,3,2,1,0
G01,2026-09-07 19:00,omar_h,B,L,11,5,4,0,1
G01,2026-09-07 19:00,tyler_r,B,L,7,3,2,0,1
G02,2026-09-09 19:00,nina_p,A,W,11,5,3,2,0
G02,2026-09-09 19:00,omar_h,A,W,11,4,3,0,3
G02,2026-09-09 19:00,tyler_r,A,W,9,6,3,1,2
G02,2026-09-09 19:00,andre_l,B,L,6,4,3,0,2
G02,2026-09-09 19:00,rookie_jen,B,L,4,3,3,1,0
G02,2026-09-09 19:00,bree_c,B,L,12,4,4,0,1
G03,2026-09-11 19:00,mia_f,A,W,7,3,2,0,1
G03,2026-09-11 19:00,rookie_ray,A,W,5,4,3,1,2
G03,2026-09-11 19:00,andre_l,A,W,5,2,1,1,0
G03,2026-09-11 19:00,zoe_k,B,L,8,5,2,0,2
G03,2026-09-11 19:00,luis_g,B,L,3,4,3,1,2
G03,2026-09-11 19:00,rookie_jen,B,L,5,4,2,0,1
G04,2026-09-14 19:00,nina_p,A,W,14,6,5,1,3
G04,2026-09-14 19:00,omar_h,A,W,12,6,2,1,2
G04,2026-09-14 19:00,jaylen_w,A,W,15,6,5,0,2
G04,2026-09-14 19:00,rookie_ray,B,L,9,5,3,1,2
G04,2026-09-14 19:00,rookie_jen,B,L,5,3,1,1,1
G04,2026-09-14 19:00,rico_s,B,L,15,7,4,2,1
G05,2026-09-16 19:00,bree_c,A,W,13,5,4,2,3
G05,2026-09-16 19:00,andre_l,A,W,8,4,3,0,1
G05,2026-09-16 19:00,nina_p,A,W,9,4,3,1,3
G05,2026-09-16 19:00,zoe_k,B,L,9,7,4,1,1
G05,2026-09-16 19:00,tyler_r,B,L,7,3,2,1,2
G05,2026-09-16 19:00,omar_h,B,L,12,7,5,0,3
G06,2026-09-18 19:00,tyler_r,A,W,8,4,2,2,0
G06,2026-09-18 19:00,jaylen_w,A,W,12,3,4,1,2
G06,2026-09-18 19:00,omar_h,A,W,11,6,5,0,2
G06,2026-09-18 19:00,rookie_ray,B,L,6,4,1,1,0
G06,2026-09-18 19:00,rookie_jen,B,L,5,4,1,0,1
G06,2026-09-18 19:00,bree_c,B,L,14,6,6,0,3
G07,2026-09-20 19:00,omar_h,A,L,12,4,3,0,1
G07,2026-09-20 19:00,nina_p,A,L,12,7,5,2,2
G07,2026-09-20 19:00,bree_c,A,L,13,6,3,1,2
G07,2026-09-20 19:00,jaylen_w,B,W,12,5,4,2,3
G07,2026-09-20 19:00,rico_s,B,W,13,6,4,2,2
G07,2026-09-20 19:00,kev_m,B,W,15,8,5,2,3
G08,2026-09-23 19:00,tyler_r,A,L,8,3,2,2,2
G08,2026-09-23 19:00,rookie_ray,A,L,7,6,4,0,3
G08,2026-09-23 19:00,andre_l,A,L,8,6,2,0,3
G08,2026-09-23 19:00,bree_c,B,W,14,6,5,1,2
G08,2026-09-23 19:00,rookie_jen,B,W,5,1,2,0,0
G08,2026-09-23 19:00,nina_p,B,W,11,5,2,2,3
G09,2026-09-25 19:00,rookie_ray,A,W,5,4,4,1,1
G09,2026-09-25 19:00,andre_l,A,W,6,3,2,0,0
G09,2026-09-25 19:00,tyler_r,A,W,10,3,4,2,2
G09,2026-09-25 19:00,zoe_k,B,L,7,3,3,0,1
G09,2026-09-25 19:00,mia_f,B,L,7,3,2,0,1
G09,2026-09-25 19:00,luis_g,B,L,3,1,1,0,0
G10,2026-09-27 19:00,mia_f,A,W,8,3,2,0,3
G10,2026-09-27 19:00,omar_h,A,W,11,5,4,2,3
G10,2026-09-27 19:00,nina_p,A,W,13,7,3,1,2
G10,2026-09-27 19:00,andre_l,B,L,7,4,1,1,2
G10,2026-09-27 19:00,tyler_r,B,L,9,5,5,1,0
G10,2026-09-27 19:00,zoe_k,B,L,8,5,4,0,2
G11,2026-09-29 19:00,rookie_jen,A,W,3,2,3,0,0
G11,2026-09-29 19:00,rookie_ray,A,W,8,4,3,0,1
G11,2026-09-29 19:00,zoe_k,A,W,9,6,3,1,1
G11,2026-09-29 19:00,andre_l,B,L,7,4,2,0,2
G11,2026-09-29 19:00,luis_g,B,L,5,4,3,0,2
G11,2026-09-29 19:00,mia_f,B,L,8,3,3,0,2
G12,2026-10-02 19:00,kev_m,A,L,19,10,6,2,3
G12,2026-10-02 19:00,omar_h,A,L,8,4,2,2,2
G12,2026-10-02 19:00,jaylen_w,A,L,15,8,5,0,3
G12,2026-10-02 19:00,bree_c,B,W,14,6,5,0,3
G12,2026-10-02 19:00,rico_s,B,W,10,5,4,0,2
G12,2026-10-02 19:00,dev_o,B,W,19,9,5,2,5
G13,2026-10-04 19:00,dev_o,A,L,15,7,5,1,3
G13,2026-10-04 19:00,kev_m,A,L,17,7,4,1,4
G13,2026-10-04 19:00,rico_s,A,L,11,6,5,1,1
G13,2026-10-04 19:00,bree_c,B,W,10,4,2,1,3
G13,2026-10-04 19:00,jaylen_w,B,W,18,9,7,1,2
G13,2026-10-04 19:00,tasha_b,B,W,19,8,7,3,3
G14,2026-10-06 19:00,luis_g,A,L,4,4,2,0,2
G14,2026-10-06 19:00,zoe_k,A,L,8,3,3,0,1
G14,2026-10-06 19:00,andre_l,A,L,7,3,1,1,0
G14,2026-10-06 19:00,rookie_ray,B,W,6,4,1,1,2
G14,2026-10-06 19:00,mia_f,B,W,8,3,3,1,1
G14,2026-10-06 19:00,tyler_r,B,W,11,5,5,2,1
G15,2026-10-08 19:00,andre_l,A,W,6,3,2,1,0
G15,2026-10-08 19:00,rookie_jen,A,W,5,1,1,0,0
G15,2026-10-08 19:00,rookie_ray,A,W,10,4,4,0,2
G15,2026-10-08 19:00,luis_g,B,L,4,2,1,1,1
G15,2026-10-08 19:00,mia_f,B,L,7,4,2,0,0
G15,2026-10-08 19:00,zoe_k,B,L,7,3,2,0,1
G16,2026-10-11 19:00,mia_f,A,L,6,2,2,1,0
G16,2026-10-11 19:00,rookie_jen,A,L,5,4,1,0,0
G16,2026-10-11 19:00,luis_g,A,L,4,4,3,1,0
G16,2026-10-11 19:00,andre_l,B,W,6,4,2,0,0
G16,2026-10-11 19:00,rookie_ray,B,W,9,5,4,1,1
G16,2026-10-11 19:00,zoe_k,B,W,6,4,3,1,2
G17,2026-10-13 19:00,jaylen_w,A,L,13,6,3,0,1
G17,2026-10-13 19:00,kev_m,A,L,18,7,4,1,4
G17,2026-10-13 19:00,marcus_j,A,L,21,11,6,2,5
G17,2026-10-13 19:00,tasha_b,B,W,23,12,7,2,4
G17,2026-10-13 19:00,rico_s,B,W,16,7,4,1,3
G17,2026-10-13 19:00,dev_o,B,W,15,7,6,2,2
G18,2026-10-15 19:00,zoe_k,A,L,8,4,3,0,2
G18,2026-10-15 19:00,tyler_r,A,L,9,3,2,2,1
G18,2026-10-15 19:00,bree_c,A,L,15,6,5,1,3
G18,2026-10-15 19:00,omar_h,B,W,13,6,3,3,2
G18,2026-10-15 19:00,nina_p,B,W,9,4,4,2,2
G18,2026-10-15 19:00,jaylen_w,B,W,19,8,5,3,4
"""
}
#endif
