import Foundation
/// Represents a battery advertised by one Bluetooth service instance.
public struct Battery {
    public let name: String
    public let level: UInt8?
    public init(name: String, data: Data) {
        self.name = name
        self.level = data.count == 1 ? data.first.flatMap { $0 <= 100 ? $0 : nil } : nil
    }
}
/// Produces the SwiftBar menu for a keyboard battery snapshot.
public struct Menu {
    public let name: String
    public let batteries: [Battery]
    public let status: String
    private let labels: [String: String]
    public init(name: String, batteries: [Battery], status: String, labels: [String: String] = [:]) {
        self.name = name
        self.batteries = batteries
        self.status = status
        self.labels = labels
    }
    public var text: String {
        let title = batteries.isEmpty ? "—" : batteries.map { description($0) }.joined(separator: " · ")
        let color = batteries.contains { ($0.level ?? 100) <= 20 } ? " color=#D97706" : ""
        var lines = ["⌨ \(title) | symbolize=false\(color)", "---", "\(clean(name)) | symbolize=false"]
        lines += batteries.map { "\(description($0)) | symbolize=false" }
        if batteries.count == 1 {
            lines.append("Only one battery service — check RMK peripheral battery reporting")
        }
        if batteries.contains(where: { $0.level == nil }) {
            lines.append("— means the firmware has not provided a valid battery level")
        }
        if !status.isEmpty { lines.append("\(clean(status)) | symbolize=false") }
        lines += [
            "---", "Refresh | refresh=true",
            "Bluetooth Settings | href=x-apple.systempreferences:com.apple.BluetoothSettings",
        ]
        return lines.joined(separator: "\n") + "\n"
    }
    private func description(_ battery: Battery) -> String {
        "\(clean(labels[battery.name] ?? battery.name)) \(battery.level.map { "\($0)%" } ?? "—")"
    }
    private func clean(_ text: String) -> String {
        String(
            text.unicodeScalars.map { scalar in
                CharacterSet.controlCharacters.contains(scalar) || scalar == "|" ? " " : String(scalar)
            }.joined().prefix(100))
    }
}
