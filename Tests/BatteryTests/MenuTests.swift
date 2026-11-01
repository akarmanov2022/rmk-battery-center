import Foundation
import XCTest
@testable import Battery
/// Verifies the battery information presented to SwiftBar.
final class MenuTests: XCTestCase {
    func testMenuUsesCustomHalfNames() {
        XCTAssertTrue(
            Menu(
                name: "OP36",
                batteries: [
                    Battery(name: "Left", data: Data([67])), Battery(name: "Right", data: Data([39])),
                ], status: "", labels: ["Left": "L", "Right": "R"]
            ).text.contains("L 67% · R 39%"),
            "Menu does not use the configured half names"
        )
    }
    func testMenuEscapesCustomHalfNames() {
        XCTAssertFalse(
            Menu(
                name: "OP36", batteries: [Battery(name: "Left", data: Data([51]))], status: "",
                labels: ["Left": "L | bash=/tmp/command\n---"]
            ).text.contains("| bash="),
            "Menu does not protect the SwiftBar protocol from custom half names"
        )
    }
    func testMenuReadsBatteryFromDataSlice() {
        XCTAssertTrue(
            Menu(name: "OP36", batteries: [Battery(name: "Left", data: Data([9, 57]).dropFirst())], status: "")
                .text.contains("Left 57%"),
            "Menu does not read a battery value from a data slice"
        )
    }
    func testMenuPreservesBothBatteriesWithTheSameServiceUUID() {
        XCTAssertTrue(
            Menu(
                name: "OP36",
                batteries: [
                    Battery(name: "Left", data: Data([73])),
                    Battery(name: "Right", data: Data([41])),
                ], status: ""
            ).text.contains("Left 73% · Right 41%"),
            "Menu does not preserve both battery services"
        )
    }
    func testMenuDistinguishesUnknownBatteryFromEmptyBattery() {
        XCTAssertTrue(
            Menu(
                name: "OP36",
                batteries: [
                    Battery(name: "Central", data: Data([0])),
                    Battery(name: "Peripheral 0", data: Data([255])),
                ], status: ""
            ).text.contains("Central 0% · Peripheral 0 —"),
            "Menu does not distinguish an unknown battery from an empty battery"
        )
    }
    func testMenuRejectsMalformedBatteryValues() {
        XCTAssertTrue(
            Menu(name: "OP36", batteries: [Battery(name: "Left", data: Data([47, 2]))], status: "")
                .text.contains("Left —"),
            "Menu does not reject malformed battery values"
        )
    }
    func testMenuWarnsWhenOnlyOneBatteryIsAvailable() {
        XCTAssertTrue(
            Menu(name: "OP36", batteries: [Battery(name: "Central", data: Data([86]))], status: "")
                .text.contains("Only one battery service"),
            "Menu does not explain the missing second battery"
        )
    }
    func testMenuEscapesBluetoothNames() {
        XCTAssertFalse(
            Menu(
                name: "OP36\n---",
                batteries: [
                    Battery(name: "Right | bash=/tmp/command\n---", data: Data([62]))
                ], status: ""
            ).text.contains("| bash="),
            "Menu does not protect the SwiftBar protocol from Bluetooth names"
        )
    }
    func testMenuMarksLowCharge() {
        XCTAssertTrue(
            Menu(name: "OP36", batteries: [Battery(name: "Left", data: Data([14]))], status: "")
                .text.components(separatedBy: "\n")[0].contains("color=#D97706"),
            "Menu does not mark low charge"
        )
    }
    func testMenuExplainsConnectionFailureWithoutShowingCachedCharge() {
        XCTAssertTrue(
            Menu(name: "OP36", batteries: [], status: "Keyboard is not connected over Bluetooth")
                .text.contains("Keyboard is not connected over Bluetooth"),
            "Menu does not explain the connection failure"
        )
    }
}
