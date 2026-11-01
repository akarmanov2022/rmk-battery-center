// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "RMKBatteryCenter",
    platforms: [.macOS(.v12)],
    products: [.executable(name: "rmk-battery", targets: ["BatteryApp"])],
    targets: [
        .target(name: "Battery"),
        .executableTarget(name: "BatteryApp", dependencies: ["Battery"]),
        .testTarget(name: "BatteryTests", dependencies: ["Battery"]),
    ]
)
