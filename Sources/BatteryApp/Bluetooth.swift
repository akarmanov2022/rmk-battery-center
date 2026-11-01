import Battery
import CoreBluetooth
import Foundation
/// Collects separate Battery Service instances from a connected keyboard.
final class Bluetooth: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    private var central: CBCentralManager!
    private var snapshot = Snapshot()
    private let name: String
    private let identifier: String
    init(name: String, identifier: String) {
        self.name = name
        self.identifier = identifier
        super.init()
        central = CBCentralManager(
            delegate: self, queue: nil, options: [CBCentralManagerOptionShowPowerAlertKey: false])
    }
    func menu(labels: [String: String]) -> Menu {
        Menu(
            name: snapshot.peripheral?.name ?? name,
            batteries: snapshot.batteries.isEmpty
                ? snapshot.readings.map {
                    Battery(name: $0.name, data: $0.data)
                } : snapshot.batteries,
            status: [snapshot.status, snapshot.warning].filter { !$0.isEmpty }.joined(separator: " · "), labels: labels)
    }
    var complete: Bool { snapshot.complete }
    func close() {
        if let peripheral = snapshot.peripheral { central.cancelPeripheralConnection(peripheral) }
    }
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            let peripherals = central.retrieveConnectedPeripherals(withServices: [
                CBUUID(string: "180F"), CBUUID(string: "1812"),
            ])
            let matches = peripherals.filter {
                identifier.isEmpty
                    ? ($0.name ?? "").localizedCaseInsensitiveCompare(name) == .orderedSame
                    : $0.identifier.uuidString.caseInsensitiveCompare(identifier) == .orderedSame
            }
            guard matches.count == 1, let peripheral = matches.first else {
                snapshot.status =
                    matches.isEmpty
                    ? "Keyboard is not connected over Bluetooth — check the configured name"
                    : "Multiple keyboards have this name — configure the Bluetooth identifier"
                snapshot.complete = true
                return
            }
            snapshot.peripheral = peripheral
            snapshot.status = "Battery read timed out — wake the keyboard and refresh"
            peripheral.delegate = self
            central.connect(peripheral)
        case .unauthorized:
            snapshot.status = "Allow RMK Battery Center in System Settings → Privacy & Security → Bluetooth"
            snapshot.complete = true
        case .poweredOff:
            snapshot.status = "Bluetooth is turned off"
            snapshot.complete = true
        case .unsupported:
            snapshot.status = "Bluetooth Low Energy is unavailable"
            snapshot.complete = true
        default:
            snapshot.status = "Bluetooth is starting — refresh shortly"
        }
    }
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([
            CBUUID(string: "180F"), CBUUID(string: "1812"), CBUUID(string: "8cfa65ff-3b6d-55f3-8b67-49693930420d"),
        ])
    }
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        snapshot.status = "Could not open the keyboard Bluetooth connection"
        snapshot.complete = true
    }
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        snapshot.readings = []
        snapshot.status = "Keyboard disconnected during the battery read"
        snapshot.complete = true
    }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil, let services = peripheral.services, !services.isEmpty else {
            snapshot.status = "No readable battery services — check RMK firmware configuration"
            snapshot.complete = true
            return
        }
        if let service = services.first(where: { $0.uuid == CBUUID(string: "8cfa65ff-3b6d-55f3-8b67-49693930420d") })
            ?? services.first(where: { $0.uuid == CBUUID(string: "1812") })
        {
            snapshot.status = "Ergohaven battery query timed out — check firmware support and refresh"
            snapshot.exchange = Exchange(peripheral: peripheral, service: service) { [weak self] batteries, status in
                guard let self = self else { return }
                if batteries.isEmpty {
                    self.snapshot.warning = status
                    peripheral.delegate = self
                    self.standard(peripheral)
                } else {
                    self.snapshot.batteries = batteries
                    self.snapshot.status = status
                    self.snapshot.complete = true
                }
            }
            snapshot.exchange?.start()
        } else {
            standard(peripheral)
        }
    }
    private func standard(_ peripheral: CBPeripheral) {
        let services = (peripheral.services ?? []).filter { $0.uuid == CBUUID(string: "180F") }
        guard !services.isEmpty else {
            snapshot.status = "No readable battery services — check RMK firmware configuration"
            snapshot.complete = true
            return
        }
        snapshot.pending = services.count
        snapshot.status = "Battery read timed out — wake the keyboard and refresh"
        for service in services {
            peripheral.discoverCharacteristics([CBUUID(string: "2A19")], for: service)
        }
    }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if error != nil { snapshot.failed = true }
        for characteristic in service.characteristics ?? [] where characteristic.uuid == CBUUID(string: "2A19") {
            snapshot.readings.append(
                Reading(characteristic: characteristic, name: "Battery \(snapshot.readings.count + 1)"))
            snapshot.pending += 2
            peripheral.readValue(for: characteristic)
            peripheral.discoverDescriptors(for: characteristic)
        }
        settled()
    }
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let index = snapshot.readings.firstIndex(where: { $0.characteristic === characteristic }) {
            snapshot.readings[index].data = error == nil ? characteristic.value ?? Data() : Data()
        }
        if error != nil { snapshot.failed = true }
        settled()
    }
    func peripheral(
        _ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?
    ) {
        for descriptor in characteristic.descriptors ?? [] where descriptor.uuid == CBUUID(string: "2901") {
            snapshot.pending += 1
            peripheral.readValue(for: descriptor)
        }
        settled()
    }
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor descriptor: CBDescriptor, error: Error?) {
        if let index = snapshot.readings.firstIndex(where: { $0.characteristic === descriptor.characteristic }),
            let description = descriptor.value as? String,
            !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            snapshot.readings[index].name = description
        }
        settled()
    }
    private func settled() {
        snapshot.pending -= 1
        if snapshot.pending == 0 {
            snapshot.complete = true
            snapshot.status =
                snapshot.failed
                ? "Some battery values could not be read — refresh to retry"
                : snapshot.readings.isEmpty ? "Battery Level characteristic is missing from the firmware" : ""
        }
    }
}
/// Holds transient state for one bounded Bluetooth read.
private struct Snapshot {
    var peripheral: CBPeripheral?
    var readings: [Reading] = []
    var batteries: [Battery] = []
    var exchange: Exchange?
    var warning = ""
    var status = "Bluetooth permission or initialization timed out — refresh to retry"
    var pending = 0
    var complete = false
    var failed = false
}
/// Keeps a battery associated with its characteristic object rather than its shared UUID.
private struct Reading {
    let characteristic: CBCharacteristic
    var name: String
    var data = Data()
}
