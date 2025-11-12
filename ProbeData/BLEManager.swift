//
//  BLEManager.swift
//  ARSurgery
//
//  Created by Barath Balamurugan on 11/11/25.
//

import Foundation
import CoreBluetooth
import Combine

final class BLEManager: NSObject, ObservableObject {
    // MARK: - BLE IDs
    private let deviceName = "ESP32_BLE"
    private let serviceUUID = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
    private let charUUID    = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")

    // MARK: - Published sensor values
    @Published var roll:  Float = .nan
    @Published var pitch: Float = .nan
    @Published var yaw:   Float = .nan
    @Published var depth: Float = .nan

    @Published var statusText: String = "Idle"
    @Published var isConnected: Bool = false

    // MARK: - CoreBluetooth
    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var notifyChar: CBCharacteristic?

    // Buffer in case notifications arrive fragmented (rare, but safe)
    private var textBuffer = Data()

    // Reconnect backoff
    private var reconnectDelay: TimeInterval = 0.5

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
    }

    func start() {
        if central.state == .poweredOn {
            scan()
        } else {
            statusText = "Waiting for Bluetooth..."
        }
    }

    func stop() {
        if let p = peripheral {
            central.cancelPeripheralConnection(p)
        }
        central.stopScan()
        statusText = "Stopped"
    }

    private func scan() {
        statusText = "Scanning..."
        central.scanForPeripherals(withServices: [serviceUUID],
                                   options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
    }

    private func connect(_ p: CBPeripheral) {
        statusText = "Connecting to \(p.name ?? "device")..."
        peripheral = p
        p.delegate = self
        central.connect(p, options: nil)
    }

    private func subscribe(_ c: CBCharacteristic, on p: CBPeripheral) {
        notifyChar = c
        p.setNotifyValue(true, for: c)
    }

    private func parseCSVLine(_ line: String) {
        // Expected "roll,pitch,yaw,depth" as floats
        let parts = line.split(separator: ",", omittingEmptySubsequences: true)
        guard parts.count >= 4,
              let r = Float(parts[0]),
              let p = Float(parts[1]),
              let y = Float(parts[2]),
              let d = Float(parts[3]) else { return }

        roll  = r
        pitch = p
        yaw   = y
        depth = d
    }

    private func handleIncoming(_ data: Data) {
        // Notifications are typically whole strings; still handle newlines/fragmentation.
        textBuffer.append(data)
        if let s = String(data: textBuffer, encoding: .utf8) {
            // Split on newline if your ESP ever adds '\n'; otherwise process as a full frame.
            if let newlineRange = s.range(of: "\n") {
                // process each complete line
                let lines = s.split(separator: "\n").map(String.init)
                for line in lines { parseCSVLine(line) }
                textBuffer.removeAll(keepingCapacity: true)
            } else {
                // single frame with CSV only
                parseCSVLine(s)
                textBuffer.removeAll(keepingCapacity: true)
            }
        } else {
            // If UTF8 fails, clear the buffer to avoid growth
            textBuffer.removeAll(keepingCapacity: true)
        }
    }
}

// MARK: - CBCentralManagerDelegate
extension BLEManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            scan()
        case .unauthorized: statusText = "Bluetooth unauthorized"
        case .unsupported:  statusText = "Bluetooth unsupported"
        case .poweredOff:   statusText = "Bluetooth powered off"
        default:            statusText = "Bluetooth state: \(central.state.rawValue)"
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover p: CBPeripheral,
                        advertisementData: [String : Any],
                        rssi RSSI: NSNumber) {
        // If you didn’t filter by service, you can also match name here:
        let name = p.name ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? ""
        if name == deviceName || (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID])?.contains(serviceUUID) == true {
            central.stopScan()
            connect(p)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect p: CBPeripheral) {
        isConnected = true
        statusText = "Discovering services..."
        reconnectDelay = 0.5
        p.discoverServices([serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect p: CBPeripheral, error: Error?) {
        isConnected = false
        statusText = "Connect failed: \(error?.localizedDescription ?? "unknown")"
        scheduleReconnect()
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral p: CBPeripheral, error: Error?) {
        isConnected = false
        statusText = "Disconnected\(error != nil ? ": \(error!.localizedDescription)" : "")"
        notifyChar = nil
        scheduleReconnect()
    }

    private func scheduleReconnect() {
        guard peripheral != nil else { scan(); return }
        let delay = reconnectDelay
        reconnectDelay = min(reconnectDelay * 2, 10.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self else { return }
            if let p = self.peripheral {
                self.statusText = "Reconnecting..."
                self.central.connect(p, options: nil)
            } else {
                self.scan()
            }
        }
    }
}

// MARK: - CBPeripheralDelegate
extension BLEManager: CBPeripheralDelegate {
    func peripheral(_ p: CBPeripheral, didDiscoverServices error: Error?) {
        if let e = error { statusText = "Service discovery error: \(e.localizedDescription)"; scheduleReconnect(); return }
        guard let services = p.services else { scheduleReconnect(); return }
        if let svc = services.first(where: { $0.uuid == serviceUUID }) {
            p.discoverCharacteristics([charUUID], for: svc)
        } else {
            statusText = "Service 180C not found"; scheduleReconnect()
        }
    }

    func peripheral(_ p: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let e = error { statusText = "Char discovery error: \(e.localizedDescription)"; scheduleReconnect(); return }
        guard let chars = service.characteristics,
              let c = chars.first(where: { $0.uuid == charUUID }) else {
            statusText = "Char 2A56 not found"; scheduleReconnect(); return
        }
        subscribe(c, on: p)
        statusText = "Subscribed"
    }

    func peripheral(_ p: CBPeripheral, didUpdateValueFor c: CBCharacteristic, error: Error?) {
        if let e = error { statusText = "Update error: \(e.localizedDescription)"; return }
        guard let data = c.value else { return }
        handleIncoming(data)
    }

    func peripheral(_ p: CBPeripheral, didUpdateNotificationStateFor c: CBCharacteristic, error: Error?) {
        if let e = error { statusText = "Notify error: \(e.localizedDescription)"; return }
        if !c.isNotifying { statusText = "Notif stopped"; central.cancelPeripheralConnection(p) }
    }
}
