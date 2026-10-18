import Foundation

struct AppConstants {
    static let playerRole = "player"
    static let employeeRole = "employee"
    /// Requested employee access but not yet approved by an existing staff member. Treated as a
    /// regular player everywhere except the approval UI in EditPlayerDetailView.
    static let employeePendingRole = "employee_pending"
    /// Full access, no approval required. Not yet self-service — assigned directly in data today.
    /// Once Employee/Manager/Administrator tiers exist, Administrator stays the top, unrestricted tier.
    static let administratorRole = "administrator"

    /// The owner's account always registers as administrator, regardless of the employee toggle
    /// or whether other staff already exist — see LoginView.register().
    static let ownerUsername = "GailanH"

    /// Roles with staff privileges (Add Game, Edit Player Accounts, approvals, coaching management).
    static let staffRoles: Set<String> = [employeeRole, administratorRole]

    static func isStaff(_ role: String?) -> Bool {
        guard let role else { return false }
        return staffRoles.contains(role)
    }

    static let competitiveMembership = "Competitive"
    static let casualMembership = "Casual"
    static let deactivatedMembership = "Deactivated"

    /// Only Competitive members participate in the ranked ladder — Casual members play,
    /// train, and book coaching, but never accumulate RP or appear in ranked standings.
    static func isRanked(_ membership: String?) -> Bool {
        membership == competitiveMembership
    }
}
