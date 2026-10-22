#if DEBUG
import Foundation
import CoreData

/// TEST TOOL, Debug builds only. A ready-made league for trying the leaderboard and rank
/// timeline: 16 Competitive players (Rookie to Elite, two still in placement), 2 Casual
/// members, and 41 three-on-three games from Sep 7 to Oct 18 (about 15 per player) with
/// promotions, demotions, both placements finished, and an underdog win to finish (G41: three
/// Silvers beat three Gold-or-better players). Every test account's password is `totl-demo-123`.
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
        backdateSeasonStart(in: context)
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

    /// The sample games are backdated (Sep 7 – Oct 18). If the current season was created later
    /// (e.g. by a game recorded today), start it at the first sample game so the timeline and
    /// Seasons screen read sensibly.
    private static func backdateSeasonStart(in context: NSManagedObjectContext) {
        guard let season = SeasonManager.activeSeason(in: context),
              let firstGame = ((season.matches as? Set<Match>) ?? []).compactMap(\.date).min(),
              let start = season.startDate, firstGame < start else { return }
        season.startDate = firstGame
        season.endDate = SeasonManager.scheduledEnd(from: firstGame)
        try? context.save()
    }

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
G01,2026-09-07 18:00,marcus_j,A,W,14,9,6,3,4
G01,2026-09-07 18:00,zoe_k,A,W,7,3,2,1,0
G01,2026-09-07 18:00,luis_g,A,W,5,5,4,1,2
G01,2026-09-07 18:00,rico_s,B,L,8,4,2,2,1
G01,2026-09-07 18:00,tyler_r,B,L,7,2,4,0,1
G01,2026-09-07 18:00,rookie_jen,B,L,6,2,2,1,0
G02,2026-09-08 19:30,tasha_b,A,L,18,9,5,1,3
G02,2026-09-08 19:30,bree_c,A,L,14,8,5,2,4
G02,2026-09-08 19:30,omar_h,A,L,9,3,4,0,0
G02,2026-09-08 19:30,dev_o,B,W,19,9,5,0,3
G02,2026-09-08 19:30,kev_m,B,W,20,8,7,3,5
G02,2026-09-08 19:30,nina_p,B,W,14,6,5,0,2
G03,2026-09-09 18:00,tasha_b,A,W,21,10,7,4,3
G03,2026-09-09 18:00,mia_f,A,W,8,5,1,0,0
G03,2026-09-09 18:00,luis_g,A,W,4,1,3,1,0
G03,2026-09-09 18:00,dev_o,B,L,15,8,3,2,4
G03,2026-09-09 18:00,andre_l,B,L,5,3,3,0,0
G03,2026-09-09 18:00,rookie_ray,B,L,9,4,2,0,0
G04,2026-09-10 19:30,jaylen_w,A,L,9,4,4,0,2
G04,2026-09-10 19:30,tyler_r,A,L,11,5,3,1,0
G04,2026-09-10 19:30,andre_l,A,L,3,3,2,0,1
G04,2026-09-10 19:30,omar_h,B,W,11,3,4,1,2
G04,2026-09-10 19:30,nina_p,B,W,14,7,4,2,2
G04,2026-09-10 19:30,rookie_jen,B,W,4,2,2,0,1
G05,2026-09-11 18:00,marcus_j,A,L,23,12,8,3,6
G05,2026-09-11 18:00,zoe_k,A,L,7,4,2,0,2
G05,2026-09-11 18:00,mia_f,A,L,8,4,4,1,1
G05,2026-09-11 18:00,kev_m,B,W,19,7,7,2,4
G05,2026-09-11 18:00,bree_c,B,W,15,7,2,1,2
G05,2026-09-11 18:00,rookie_ray,B,W,9,4,2,2,1
G06,2026-09-12 19:30,tasha_b,A,W,21,11,8,3,3
G06,2026-09-12 19:30,jaylen_w,A,W,11,6,3,0,1
G06,2026-09-12 19:30,mia_f,A,W,7,3,3,1,2
G06,2026-09-12 19:30,kev_m,B,L,15,7,6,1,2
G06,2026-09-12 19:30,rico_s,B,L,11,5,4,2,2
G06,2026-09-12 19:30,rookie_jen,B,L,5,4,1,1,2
G07,2026-09-13 18:00,marcus_j,A,W,19,9,6,1,5
G07,2026-09-13 18:00,zoe_k,A,W,6,3,3,0,0
G07,2026-09-13 18:00,luis_g,A,W,6,3,3,1,2
G07,2026-09-13 18:00,nina_p,B,L,13,5,2,2,2
G07,2026-09-13 18:00,omar_h,B,L,9,5,3,0,2
G07,2026-09-13 18:00,rookie_ray,B,L,9,5,5,1,2
G08,2026-09-14 19:30,rico_s,A,W,13,6,5,1,1
G08,2026-09-14 19:30,tyler_r,A,W,7,3,4,0,0
G08,2026-09-14 19:30,zoe_k,A,W,7,4,3,1,1
G08,2026-09-14 19:30,jaylen_w,B,L,12,6,5,1,1
G08,2026-09-14 19:30,bree_c,B,L,8,4,1,1,1
G08,2026-09-14 19:30,rookie_ray,B,L,8,3,3,0,1
G09,2026-09-15 18:00,marcus_j,A,W,22,10,6,2,6
G09,2026-09-15 18:00,tyler_r,A,W,9,6,5,0,1
G09,2026-09-15 18:00,andre_l,A,W,6,4,2,1,1
G09,2026-09-15 18:00,dev_o,B,L,15,7,4,1,4
G09,2026-09-15 18:00,omar_h,B,L,12,5,3,2,2
G09,2026-09-15 18:00,rookie_jen,B,L,4,3,2,0,1
G10,2026-09-16 19:30,tasha_b,A,W,16,8,4,2,4
G10,2026-09-16 19:30,rico_s,A,W,11,6,4,1,1
G10,2026-09-16 19:30,bree_c,A,W,7,3,3,2,1
G10,2026-09-16 19:30,kev_m,B,L,17,8,5,3,2
G10,2026-09-16 19:30,dev_o,B,L,16,7,5,1,2
G10,2026-09-16 19:30,luis_g,B,L,4,1,1,1,0
G11,2026-09-17 18:00,tasha_b,A,L,12,7,4,2,1
G11,2026-09-17 18:00,zoe_k,A,L,5,2,2,1,2
G11,2026-09-17 18:00,andre_l,A,L,4,1,2,0,0
G11,2026-09-17 18:00,jaylen_w,B,W,15,9,6,2,3
G11,2026-09-17 18:00,nina_p,B,W,9,5,3,1,3
G11,2026-09-17 18:00,mia_f,B,W,8,4,3,0,1
G12,2026-09-18 19:30,kev_m,A,L,16,7,5,1,3
G12,2026-09-18 19:30,nina_p,A,L,11,4,2,2,1
G12,2026-09-18 19:30,tyler_r,A,L,8,3,2,1,1
G12,2026-09-18 19:30,rico_s,B,W,15,6,4,2,3
G12,2026-09-18 19:30,jaylen_w,B,W,11,6,4,2,3
G12,2026-09-18 19:30,rookie_ray,B,W,11,6,5,2,3
G13,2026-09-19 18:00,bree_c,A,L,9,3,2,1,1
G13,2026-09-19 18:00,andre_l,A,L,4,4,1,1,2
G13,2026-09-19 18:00,mia_f,A,L,7,2,1,0,1
G13,2026-09-19 18:00,omar_h,B,W,9,3,3,2,2
G13,2026-09-19 18:00,zoe_k,B,W,10,6,4,1,2
G13,2026-09-19 18:00,rookie_jen,B,W,3,3,1,0,1
G14,2026-09-20 19:30,marcus_j,A,L,16,9,7,1,5
G14,2026-09-20 19:30,nina_p,A,L,13,7,3,2,3
G14,2026-09-20 19:30,rookie_ray,A,L,6,2,3,1,0
G14,2026-09-20 19:30,dev_o,B,W,19,9,6,1,4
G14,2026-09-20 19:30,rico_s,B,W,17,8,4,2,3
G14,2026-09-20 19:30,luis_g,B,W,8,4,3,0,2
G15,2026-09-21 18:00,dev_o,A,L,10,4,2,0,2
G15,2026-09-21 18:00,bree_c,A,L,10,6,3,2,1
G15,2026-09-21 18:00,andre_l,A,L,6,4,2,0,1
G15,2026-09-21 18:00,kev_m,B,W,20,8,7,3,3
G15,2026-09-21 18:00,jaylen_w,B,W,15,7,5,2,3
G15,2026-09-21 18:00,mia_f,B,W,7,4,2,0,0
G16,2026-09-22 19:30,marcus_j,A,L,16,7,6,3,5
G16,2026-09-22 19:30,tyler_r,A,L,10,4,4,1,1
G16,2026-09-22 19:30,luis_g,A,L,5,4,3,1,0
G16,2026-09-22 19:30,tasha_b,B,W,19,9,6,3,2
G16,2026-09-22 19:30,omar_h,B,W,8,3,3,0,2
G16,2026-09-22 19:30,rookie_jen,B,W,7,4,4,0,1
G17,2026-09-23 18:00,kev_m,A,W,14,6,5,2,4
G17,2026-09-23 18:00,rookie_ray,A,W,9,5,4,2,2
G17,2026-09-23 18:00,mia_f,A,W,7,3,3,1,0
G17,2026-09-23 18:00,dev_o,B,L,14,8,4,2,4
G17,2026-09-23 18:00,rico_s,B,L,12,5,4,1,1
G17,2026-09-23 18:00,rookie_jen,B,L,4,4,2,1,2
G18,2026-09-24 19:30,marcus_j,A,L,19,10,6,1,3
G18,2026-09-24 19:30,nina_p,A,L,10,4,4,2,2
G18,2026-09-24 19:30,tyler_r,A,L,7,3,2,0,2
G18,2026-09-24 19:30,tasha_b,B,W,19,10,7,2,4
G18,2026-09-24 19:30,jaylen_w,B,W,15,6,4,2,3
G18,2026-09-24 19:30,andre_l,B,W,5,3,2,0,2
G19,2026-09-25 18:00,marcus_j,A,W,15,7,5,1,4
G19,2026-09-25 18:00,zoe_k,A,W,5,4,2,0,2
G19,2026-09-25 18:00,rookie_ray,A,W,11,6,5,2,1
G19,2026-09-25 18:00,bree_c,B,L,14,6,3,2,1
G19,2026-09-25 18:00,omar_h,B,L,10,5,3,2,0
G19,2026-09-25 18:00,luis_g,B,L,6,2,2,1,2
G20,2026-09-26 19:30,tasha_b,A,W,18,10,6,2,5
G20,2026-09-26 19:30,zoe_k,A,W,9,5,5,0,1
G20,2026-09-26 19:30,mia_f,A,W,8,4,3,0,0
G20,2026-09-26 19:30,dev_o,B,L,18,10,4,1,4
G20,2026-09-26 19:30,omar_h,B,L,11,5,3,2,1
G20,2026-09-26 19:30,luis_g,B,L,4,2,2,0,1
G21,2026-09-27 18:00,kev_m,A,L,11,5,4,0,2
G21,2026-09-27 18:00,nina_p,A,L,11,5,2,2,3
G21,2026-09-27 18:00,tyler_r,A,L,10,5,5,0,3
G21,2026-09-27 18:00,rico_s,B,W,13,5,5,1,3
G21,2026-09-27 18:00,jaylen_w,B,W,14,6,5,2,3
G21,2026-09-27 18:00,rookie_jen,B,W,4,3,3,0,2
G22,2026-09-28 19:30,kev_m,A,L,17,8,4,1,2
G22,2026-09-28 19:30,omar_h,A,L,9,3,3,1,2
G22,2026-09-28 19:30,andre_l,A,L,6,3,2,0,2
G22,2026-09-28 19:30,jaylen_w,B,W,16,8,4,2,4
G22,2026-09-28 19:30,bree_c,B,W,10,5,4,1,2
G22,2026-09-28 19:30,rookie_jen,B,W,5,3,1,1,1
G23,2026-09-29 18:00,marcus_j,A,W,22,12,6,3,5
G23,2026-09-29 18:00,tyler_r,A,W,8,3,3,0,0
G23,2026-09-29 18:00,mia_f,A,W,9,5,2,0,1
G23,2026-09-29 18:00,rico_s,B,L,15,7,6,1,2
G23,2026-09-29 18:00,zoe_k,B,L,6,2,3,0,2
G23,2026-09-29 18:00,luis_g,B,L,5,3,3,0,1
G24,2026-09-30 19:30,marcus_j,A,L,16,8,5,2,5
G24,2026-09-30 19:30,bree_c,A,L,10,6,3,1,3
G24,2026-09-30 19:30,nina_p,A,L,8,5,3,1,1
G24,2026-09-30 19:30,tasha_b,B,W,23,10,5,2,4
G24,2026-09-30 19:30,dev_o,B,W,16,7,6,1,2
G24,2026-09-30 19:30,andre_l,B,W,8,5,3,1,0
G25,2026-10-01 18:00,tasha_b,A,W,16,8,6,2,4
G25,2026-10-01 18:00,zoe_k,A,W,7,2,3,1,0
G25,2026-10-01 18:00,rookie_ray,A,W,7,4,4,0,0
G25,2026-10-01 18:00,bree_c,B,L,10,5,2,1,3
G25,2026-10-01 18:00,omar_h,B,L,10,4,3,1,1
G25,2026-10-01 18:00,mia_f,B,L,8,6,3,0,0
G26,2026-10-02 19:30,kev_m,A,L,12,5,4,1,4
G26,2026-10-02 19:30,rookie_ray,A,L,8,3,3,1,2
G26,2026-10-02 19:30,andre_l,A,L,7,2,2,0,2
G26,2026-10-02 19:30,dev_o,B,W,18,8,6,0,5
G26,2026-10-02 19:30,jaylen_w,B,W,14,7,5,0,2
G26,2026-10-02 19:30,luis_g,B,W,4,2,2,0,1
G27,2026-10-03 18:00,marcus_j,A,W,20,9,8,1,5
G27,2026-10-03 18:00,omar_h,A,W,9,3,4,1,2
G27,2026-10-03 18:00,luis_g,A,W,7,3,2,0,1
G27,2026-10-03 18:00,rico_s,B,L,12,5,4,0,3
G27,2026-10-03 18:00,nina_p,B,L,15,6,5,2,3
G27,2026-10-03 18:00,rookie_jen,B,L,4,3,1,1,2
G28,2026-10-04 19:30,tasha_b,A,W,16,9,4,2,4
G28,2026-10-04 19:30,nina_p,A,W,9,5,2,0,2
G28,2026-10-04 19:30,tyler_r,A,W,9,4,4,1,0
G28,2026-10-04 19:30,jaylen_w,B,L,17,7,5,0,4
G28,2026-10-04 19:30,bree_c,B,L,7,3,2,2,0
G28,2026-10-04 19:30,zoe_k,B,L,7,4,2,0,1
G29,2026-10-05 18:00,tasha_b,A,L,13,5,5,1,2
G29,2026-10-05 18:00,tyler_r,A,L,9,5,5,0,1
G29,2026-10-05 18:00,andre_l,A,L,9,5,2,0,2
G29,2026-10-05 18:00,kev_m,B,W,20,9,5,2,4
G29,2026-10-05 18:00,rico_s,B,W,11,6,4,2,2
G29,2026-10-05 18:00,rookie_jen,B,W,3,3,3,0,2
G30,2026-10-06 19:30,dev_o,A,W,17,9,5,0,5
G30,2026-10-06 19:30,zoe_k,A,W,9,4,2,1,2
G30,2026-10-06 19:30,rookie_ray,A,W,9,3,3,2,1
G30,2026-10-06 19:30,nina_p,B,L,11,6,2,0,1
G30,2026-10-06 19:30,tyler_r,B,L,9,5,4,1,0
G30,2026-10-06 19:30,mia_f,B,L,9,5,3,1,2
G31,2026-10-07 18:00,jaylen_w,A,L,14,5,4,2,1
G31,2026-10-07 18:00,mia_f,A,L,7,5,3,1,1
G31,2026-10-07 18:00,luis_g,A,L,5,3,3,0,0
G31,2026-10-07 18:00,rico_s,B,W,13,5,5,1,3
G31,2026-10-07 18:00,bree_c,B,W,13,5,3,3,2
G31,2026-10-07 18:00,rookie_jen,B,W,5,4,2,1,1
G32,2026-10-08 19:30,marcus_j,A,L,21,11,7,4,5
G32,2026-10-08 19:30,bree_c,A,L,9,4,3,0,1
G32,2026-10-08 19:30,rookie_ray,A,L,7,4,2,1,1
G32,2026-10-08 19:30,dev_o,B,W,14,6,3,2,4
G32,2026-10-08 19:30,kev_m,B,W,21,9,7,1,3
G32,2026-10-08 19:30,rookie_jen,B,W,7,4,1,0,1
G33,2026-10-09 18:00,tasha_b,A,L,21,9,6,3,4
G33,2026-10-09 18:00,omar_h,A,L,11,3,2,0,2
G33,2026-10-09 18:00,andre_l,A,L,5,3,3,1,2
G33,2026-10-09 18:00,kev_m,B,W,15,8,6,1,3
G33,2026-10-09 18:00,dev_o,B,W,13,7,3,1,4
G33,2026-10-09 18:00,luis_g,B,W,7,3,3,0,0
G34,2026-10-10 19:30,jaylen_w,A,W,11,5,2,1,1
G34,2026-10-10 19:30,tyler_r,A,W,8,2,4,1,2
G34,2026-10-10 19:30,rookie_ray,A,W,8,2,2,1,2
G34,2026-10-10 19:30,rico_s,B,L,8,4,4,2,2
G34,2026-10-10 19:30,omar_h,B,L,8,3,2,1,0
G34,2026-10-10 19:30,mia_f,B,L,4,3,2,1,0
G35,2026-10-11 18:00,marcus_j,A,L,15,8,5,3,3
G35,2026-10-11 18:00,nina_p,A,L,10,4,2,1,1
G35,2026-10-11 18:00,zoe_k,A,L,5,4,3,0,1
G35,2026-10-11 18:00,kev_m,B,W,17,7,4,2,3
G35,2026-10-11 18:00,rico_s,B,W,14,7,5,2,3
G35,2026-10-11 18:00,andre_l,B,W,6,2,3,1,1
G36,2026-10-12 19:30,marcus_j,A,W,16,8,7,3,3
G36,2026-10-12 19:30,omar_h,A,W,10,5,4,1,0
G36,2026-10-12 19:30,zoe_k,A,W,10,4,3,1,3
G36,2026-10-12 19:30,bree_c,B,L,12,7,3,0,1
G36,2026-10-12 19:30,nina_p,B,L,9,3,3,0,0
G36,2026-10-12 19:30,rookie_jen,B,L,7,5,1,0,1
G37,2026-10-13 18:00,dev_o,A,W,17,9,5,2,3
G37,2026-10-13 18:00,rookie_ray,A,W,10,5,2,2,2
G37,2026-10-13 18:00,andre_l,A,W,4,2,0,0,1
G37,2026-10-13 18:00,tyler_r,B,L,7,3,2,1,0
G37,2026-10-13 18:00,zoe_k,B,L,10,4,4,0,1
G37,2026-10-13 18:00,mia_f,B,L,6,3,2,0,0
G38,2026-10-14 19:30,dev_o,A,L,15,6,3,0,4
G38,2026-10-14 19:30,rookie_ray,A,L,7,2,2,1,0
G38,2026-10-14 19:30,andre_l,A,L,5,2,3,1,2
G38,2026-10-14 19:30,jaylen_w,B,W,11,4,4,2,3
G38,2026-10-14 19:30,omar_h,B,W,10,4,3,2,0
G38,2026-10-14 19:30,luis_g,B,W,6,3,2,0,1
G39,2026-10-15 18:00,tasha_b,A,L,18,9,4,1,4
G39,2026-10-15 18:00,mia_f,A,L,9,5,2,1,1
G39,2026-10-15 18:00,luis_g,A,L,5,4,2,1,1
G39,2026-10-15 18:00,kev_m,B,W,14,7,4,2,2
G39,2026-10-15 18:00,jaylen_w,B,W,14,7,5,2,1
G39,2026-10-15 18:00,rookie_jen,B,W,4,3,1,0,1
G40,2026-10-16 19:30,marcus_j,A,W,19,10,6,3,4
G40,2026-10-16 19:30,nina_p,A,W,12,6,3,2,4
G40,2026-10-16 19:30,tyler_r,A,W,9,5,2,0,1
G40,2026-10-16 19:30,tasha_b,B,L,14,6,4,2,4
G40,2026-10-16 19:30,rico_s,B,L,11,5,4,2,1
G40,2026-10-16 19:30,rookie_jen,B,L,3,2,1,0,1
G41,2026-10-18 19:00,bree_c,A,W,13,6,4,1,2
G41,2026-10-18 19:00,nina_p,A,W,12,6,3,1,2
G41,2026-10-18 19:00,omar_h,A,W,11,5,4,1,2
G41,2026-10-18 19:00,rico_s,B,L,11,5,3,1,1
G41,2026-10-18 19:00,jaylen_w,B,L,12,5,3,1,2
G41,2026-10-18 19:00,dev_o,B,L,13,6,4,1,2
"""
}
#endif
