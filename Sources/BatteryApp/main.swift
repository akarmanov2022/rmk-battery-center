import Battery
import Foundation
let arguments = CommandLine.arguments
func argument(_ name: String, fallback: String = "") -> String {
    guard let index = arguments.firstIndex(of: name), arguments.indices.contains(index + 1) else { return fallback }
    return arguments[index + 1]
}
let labels = ["Left": argument("--left-name", fallback: "Left"), "Right": argument("--right-name", fallback: "Right")]
let text: String
if arguments.contains("--demo") {
    text =
        Menu(
            name: "OP36 · Demo",
            batteries: [
                Battery(name: "Left", data: Data([73])), Battery(name: "Right", data: Data([41])),
            ], status: "Demo values — no Bluetooth connection", labels: labels
        ).text
} else {
    let bluetooth = Bluetooth(name: argument("--name", fallback: "OP36"), identifier: argument("--id"))
    let deadline = Date().addingTimeInterval(12)
    while !bluetooth.complete && Date() < deadline {
        RunLoop.current.run(until: min(deadline, Date().addingTimeInterval(0.05)))
    }
    text = bluetooth.menu(labels: labels).text
    bluetooth.close()
}
if argument("--output").isEmpty {
    print(text, terminator: "")
} else {
    do {
        try text.write(toFile: argument("--output"), atomically: true, encoding: .utf8)
    } catch {
        fputs("Could not write the battery report: \(error.localizedDescription)\n", stderr)
        exit(1)
    }
}
