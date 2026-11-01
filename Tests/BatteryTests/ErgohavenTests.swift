import Foundation
import XCTest
@testable import Battery
/// Verifies the read-only Ergohaven battery response protocol.
final class ErgohavenTests: XCTestCase {
    func testResponsePreservesPhysicalLeftAndRightOrder() {
        XCTAssertEqual(
            Ergohaven(data: Data([8, 232, 1, 1, 3, 79, 43] + Array(repeating: 0, count: 25))).batteries.map(\.level),
            [79, 43],
            "Response does not preserve the physical battery order"
        )
    }
    func testResponseHonorsTheAvailabilityFlags() {
        XCTAssertEqual(
            Ergohaven(data: Data([8, 232, 1, 1, 1, 0, 89] + Array(repeating: 0, count: 25))).batteries.map(\.level),
            [0, nil],
            "Response does not honor the battery availability flags"
        )
    }
    func testResponseRejectsUnsupportedVersions() {
        XCTAssertTrue(
            Ergohaven(data: Data([8, 232, 1, 2, 3, 79, 43] + Array(repeating: 0, count: 25))).batteries.isEmpty,
            "Response does not reject an unsupported protocol version"
        )
    }
    func testResponseRejectsUnrelatedNotifications() {
        XCTAssertTrue(
            Ergohaven(data: Data([8, 232, 2, 1, 3, 79, 43] + Array(repeating: 0, count: 25))).batteries.isEmpty,
            "Response does not reject an unrelated notification"
        )
    }
    func testResponseRejectsTruncatedPackets() {
        XCTAssertTrue(
            Ergohaven(data: Data([8, 232, 1, 1, 3, 79, 43])).batteries.isEmpty,
            "Response does not reject a truncated packet"
        )
    }
}
