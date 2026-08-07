import Foundation
import CryptoKit
import Security

/// Utility for salting and hashing player passwords.
///
/// Passwords are never stored in plaintext. Each player gets a random salt
/// (stored in `Player.passwordSalt`), and `Player.password` stores the
/// SHA-256 hash of `salt + plaintextPassword`, hex-encoded.
enum PasswordHasher {

    /// Generates a new random, base64-encoded salt for a new account.
    static func generateSalt() -> String {
        var bytes = [UInt8](repeating: 0, count: 16)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        if status != errSecSuccess {
            // Extremely unlikely, but fall back to a UUID-derived salt rather than crash.
            return UUID().uuidString
        }
        return Data(bytes).base64EncodedString()
    }

    /// Hashes a plaintext password with the given salt using SHA-256.
    static func hash(password: String, salt: String) -> String {
        let combined = salt + password
        let digest = SHA256.hash(data: Data(combined.utf8))
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }

    /// Verifies a plaintext password attempt against a stored salt + hash.
    static func verify(password: String, salt: String, hash: String) -> Bool {
        self.hash(password: password, salt: salt) == hash
    }
}
