import Battery
import CoreBluetooth
import Foundation
/// Reads Ergohaven battery telemetry over its vendor or Vial HID service.
final class Exchange: NSObject, CBPeripheralDelegate {
    private let peripheral: CBPeripheral
    private let service: CBService
    private let completion: ([Battery], String) -> Void
    private var transfer = Transfer()
    init(peripheral: CBPeripheral, service: CBService, completion: @escaping ([Battery], String) -> Void) {
        self.peripheral = peripheral
        self.service = service
        self.completion = completion
        super.init()
    }
    func start() {
        peripheral.delegate = self
        peripheral.discoverCharacteristics(nil, for: service)
        DispatchQueue.main.asyncAfter(deadline: .now() + 7) { [weak self] in
            self?.finish([], "Ergohaven battery query timed out — check firmware support")
        }
    }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else {
            finish([], "Ergohaven battery service could not be read")
            return
        }
        if service.uuid == CBUUID(string: "1812") {
            let reports = (service.characteristics ?? []).filter { $0.uuid == CBUUID(string: "2A4D") }
            transfer.pending = reports.count
            guard !reports.isEmpty else {
                finish([], "Ergohaven Vial battery query is unavailable in this firmware")
                return
            }
            for characteristic in reports { peripheral.discoverDescriptors(for: characteristic) }
        } else {
            transfer.input = service.characteristics?.first {
                $0.uuid == CBUUID(string: "7a115e75-ae8e-51b4-9f46-dbd15af07dc3")
            }
            transfer.output = service.characteristics?.first {
                $0.uuid == CBUUID(string: "70ca58d5-fdbf-5497-a33f-d1e8e1698678")
            }
            subscribe()
        }
    }
    func peripheral(
        _ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?
    ) {
        for descriptor in characteristic.descriptors ?? [] where descriptor.uuid == CBUUID(string: "2908") {
            transfer.pending += 1
            peripheral.readValue(for: descriptor)
        }
        transfer.pending -= 1
        if transfer.pending == 0 { subscribe() }
    }
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor descriptor: CBDescriptor, error: Error?) {
        if let data = descriptor.value as? Data, Array(data) == [5, 1] {
            transfer.input = descriptor.characteristic
        }
        if let data = descriptor.value as? Data, Array(data) == [5, 2] {
            transfer.output = descriptor.characteristic
        }
        transfer.pending -= 1
        if transfer.pending == 0 { subscribe() }
    }
    func peripheral(
        _ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?
    ) {
        guard error == nil, characteristic.isNotifying else {
            finish([], "Ergohaven battery notifications could not be enabled")
            return
        }
        request()
    }
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if error != nil { finish([], "Ergohaven battery query could not be sent") }
    }
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard characteristic === transfer.input, !transfer.finished else { return }
        let batteries = Ergohaven(data: characteristic.value ?? Data()).batteries
        guard error == nil, !batteries.isEmpty else { return }
        if transfer.requests == 1 && !transfer.retrying {
            transfer.retrying = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in self?.request() }
        } else if transfer.requests >= 2 {
            finish(batteries, "")
        }
    }
    private func subscribe() {
        guard let input = transfer.input, let output = transfer.output,
            input.properties.contains(.notify), output.properties.contains(.write)
        else {
            finish([], "Ergohaven Vial battery query is unavailable in this firmware")
            return
        }
        peripheral.setNotifyValue(true, for: input)
    }
    private func request() {
        guard !transfer.finished, let output = transfer.output else { return }
        transfer.requests += 1
        peripheral.writeValue(
            Data([0x08, 0xE8, 0x01] + Array(repeating: 0, count: 29)), for: output, type: .withResponse)
    }
    private func finish(_ batteries: [Battery], _ status: String) {
        guard !transfer.finished else { return }
        transfer.finished = true
        completion(batteries, status)
    }
}
/// Tracks one battery request and its characteristic discovery.
private struct Transfer {
    var input: CBCharacteristic?
    var output: CBCharacteristic?
    var pending = 0
    var requests = 0
    var retrying = false
    var finished = false
}
