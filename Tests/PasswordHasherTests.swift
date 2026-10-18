import XCTest
@testable import Project_Comp_B

final class PasswordHasherTests: XCTestCase {

    func testVerifySucceedsWithCorrectPassword() {
        let salt = PasswordHasher.generateSalt()
        let hash = PasswordHasher.hash(password: "correct-horse", salt: salt)
        XCTAssertTrue(PasswordHasher.verify(password: "correct-horse", salt: salt, hash: hash))
    }

    func testVerifyFailsWithWrongPassword() {
        let salt = PasswordHasher.generateSalt()
        let hash = PasswordHasher.hash(password: "correct-horse", salt: salt)
        XCTAssertFalse(PasswordHasher.verify(password: "wrong-password", salt: salt, hash: hash))
    }

    func testDifferentSaltsProduceDifferentHashesForSamePassword() {
        let saltA = PasswordHasher.generateSalt()
        let saltB = PasswordHasher.generateSalt()
        XCTAssertNotEqual(saltA, saltB)

        let hashA = PasswordHasher.hash(password: "same-password", salt: saltA)
        let hashB = PasswordHasher.hash(password: "same-password", salt: saltB)
        XCTAssertNotEqual(hashA, hashB)
    }

    func testHashIsDeterministicForSameInputs() {
        let salt = "fixed-salt-for-test"
        let hash1 = PasswordHasher.hash(password: "password123", salt: salt)
        let hash2 = PasswordHasher.hash(password: "password123", salt: salt)
        XCTAssertEqual(hash1, hash2)
    }

    func testPlaintextPasswordNeverAppearsInHash() {
        let salt = PasswordHasher.generateSalt()
        let hash = PasswordHasher.hash(password: "supersecret", salt: salt)
        XCTAssertFalse(hash.contains("supersecret"))
    }
}
