import Foundation
/// Decodes the Ergohaven Vial battery query without changing keyboard settings.
public struct Ergohaven {
    public let batteries: [Battery]
    public init(data: Data) {
        let bytes = Array(data)
        guard bytes.count == 32, Array(bytes.prefix(4)) == [0x08, 0xE8, 0x01, 0x01] else {
            self.batteries = []
            return
        }
        self.batteries = [
            Battery(name: "Left", data: Data([bytes[4] & 1 == 1 ? bytes[5] : 255])),
            Battery(name: "Right", data: Data([bytes[4] & 2 == 2 ? bytes[6] : 255])),
        ]
    }
}
