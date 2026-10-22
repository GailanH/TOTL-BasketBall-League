import Foundation

/// Account field rules, shared by sign-up and the staff member import.
enum AccountValidation {
    static let usernameRule = "Username must be 3-20 characters: letters, numbers, and underscores only."
    static let passwordRule = "Password must be at least 8 characters."

    static func isValidUsername(_ username: String) -> Bool {
        username.range(of: #"^[A-Za-z0-9_]{3,20}$"#, options: .regularExpression) != nil
    }

    static func isValidEmail(_ email: String) -> Bool {
        email.range(of: #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#, options: .regularExpression) != nil
    }

    static func isValidPassword(_ password: String) -> Bool {
        password.count >= 8
    }
}

/// A small CSV reader: a header row plus data rows, fields split on commas, with simple
/// double-quote handling (quoted fields may contain commas; "" is a literal quote).
/// Header names are lowercased and trimmed.
struct CSVTable {
    let headers: [String]
    /// Data rows with their 1-based line number in the file (the header is line 1).
    let rows: [(line: Int, fields: [String])]

    init?(text: String) {
        let lines = text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).map(String.init)
        guard let headerIndex = lines.firstIndex(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) else {
            return nil
        }
        headers = Self.split(lines[headerIndex]).map { $0.lowercased() }
        rows = lines.enumerated()
            .filter { $0.offset > headerIndex && !$0.element.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { (line: $0.offset + 1, fields: Self.split($0.element)) }
    }

    /// The value of `column` in `fields`, trimmed; nil if the column or cell is missing.
    func value(_ column: String, in fields: [String]) -> String? {
        guard let index = headers.firstIndex(of: column), index < fields.count else { return nil }
        return fields[index]
    }

    /// Parses `2026-10-21` or `2026-10-21 18:30` in the device's time zone.
    static func parseDate(_ text: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        for format in ["yyyy-MM-dd HH:mm", "yyyy-MM-dd"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: text) { return date }
        }
        return nil
    }

    static func split(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        var chars = Array(line)[...]
        while let c = chars.popFirst() {
            if c == "\"" {
                if inQuotes, chars.first == "\"" {
                    current.append("\"")
                    chars.removeFirst()
                } else {
                    inQuotes.toggle()
                }
            } else if c == ",", !inQuotes {
                fields.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            } else {
                current.append(c)
            }
        }
        fields.append(current.trimmingCharacters(in: .whitespaces))
        return fields
    }
}
