//
//  Device.swift
//  OsmAnd Maps
//
//  Created by Oleksandr Panchenko on 25.09.2023.
//

import SwiftyBluetooth
import CoreBluetooth
import UIKit

extension Notification.Name {
    static let DeviceRSSIUpdated = NSNotification.Name("DeviceRSSIUpdated")
}

enum DeviceState: Int {
    case disconnected, connecting, connected, disconnecting
    
    var description: String {
        switch self {
        case .disconnected: return localizedString("external_device_status_disconnect")
        case .connecting: return localizedString("external_device_status_connecting")
        case .connected: return localizedString("external_device_status_connect")
        case .disconnecting: return localizedString("external_device_status_disconnecting")
        }
    }
}

class Device {
    var deviceType: DeviceType!
    var rssi = -1
    var deviceName: String = ""
    var didChangeCharacteristic: (() -> Void)? = nil
    var isSelected = false
    
    private(set) var peripheral: Peripheral!
    
    private var RSSIUpdateTimer: Timer?
    
    init(deviceType: DeviceType!,
         rssi: Int = 1,
         deviceName: String = "",
         didChangeCharacteristic: (() -> Void)? = nil,
         RSSIUpdateTimer: Timer? = nil) {
        self.deviceType = deviceType
        self.rssi = rssi
        self.deviceName = deviceName
        self.didChangeCharacteristic = didChangeCharacteristic
        self.RSSIUpdateTimer = RSSIUpdateTimer
        self.sensors = [BLEBatterySensor(device: self, sensorId: "battery_level")]
    }
    
    var id: String {
        peripheral.identifier.uuidString
    }
    
    var isConnected: Bool {
        peripheral.state == .connected
    }
    
    var sensors = [Sensor]()
    var sections: Dictionary<String, Any> = [:]
    
    class var getServiceUUID: String {
        ""
    }
    
    var getServiceConnectedImage: UIImage {
        UIImage()
    }
    
    var getDataFields: [String: String]? {
        return nil
    }
    
    var getSettingsFields: [String: Any]? {
        return nil
    }
    
    func getSupportedWidgetDataFieldTypes() -> [WidgetType]? {
        return nil
    }
    
    func update(with characteristic: CBCharacteristic, result: (Result<Void, Error>) -> Void) {
        
    }
    
    func addObservers() {
        NotificationCenter.default.removeObserver(self, name: Peripheral.PeripheralCharacteristicValueUpdate, object: nil)
        NotificationCenter.default.addObserver(forName: Peripheral.PeripheralCharacteristicValueUpdate,
                                               object: peripheral,
                                               queue: nil) { [weak self] notification in
            self?.peripheralCharacteristicValueUpdate(notification: notification as NSNotification)
        }
    }
    
    func peripheralCharacteristicValueUpdate(notification: NSNotification) {
        guard let userInfo = notification.userInfo,
              notification.userInfo?["error"] as? SBError == nil else {
            return
        }
        guard let characteristic = userInfo["characteristic"] as? CBCharacteristic else {
            return
        }
        update(with: characteristic) { [weak self] result in
            if case .success = result {
                self?.didChangeCharacteristic?()
            }
        }
    }
    
    /*
     Printing description of advertisementData:
     ▿ 6 elements
     ▿ 0 : 2 elements
     - key : "kCBAdvDataTimestamp"
     - value : 717078802.347859
     ▿ 1 : 2 elements
     - key : "kCBAdvDataRxSecondaryPHY"
     - value : 0
     ▿ 2 : 2 elements
     - key : "kCBAdvDataIsConnectable"
     - value : 1
     ▿ 3 : 2 elements
     - key : "kCBAdvDataRxPrimaryPHY"
     - value : 1
     ▿ 4 : 2 elements
     - key : "kCBAdvDataLocalName"
     - value : Heart Rate
     ▿ 5 : 2 elements
     - key : "kCBAdvDataServiceUUIDs"
     ▿ value : 2 elements
     - 0 : Device Information
     - 1 : Heart Rate
     */
}

extension Device {
    
    var state: DeviceState {
        DeviceState(rawValue: peripheral.state.rawValue) ?? .disconnected
    }
    
    func setPeripheral(peripheral: Peripheral) {
        self.peripheral = peripheral
    }
    
    func connect(withTimeout timeout: TimeInterval?, completion: @escaping ConnectPeripheralCallback) {
        peripheral.connect(withTimeout: timeout, completion: completion)
    }
    
    func disconnect(completion: @escaping DisconnectPeripheralCallback) {
        peripheral.disconnect(completion: completion)
    }
    
    func discoverServices(withUUIDs serviceUUIDs: [CBUUIDConvertible]? = nil,
                          completion: @escaping ServiceRequestCallback) {
        peripheral.discoverServices(withUUIDs: serviceUUIDs,
                                    completion: completion)
    }
    
    func discoverCharacteristics(withUUIDs characteristicUUIDs: [CBUUIDConvertible]? = nil,
                                 ofServiceWithUUID serviceUUID: CBUUIDConvertible,
                                 completion: @escaping CharacteristicRequestCallback) {
        peripheral.discoverCharacteristics(withUUIDs: characteristicUUIDs,
                                           ofServiceWithUUID: serviceUUID,
                                           completion: completion)
    }
    
    func setNotifyValue(toEnabled enabled: Bool,
                        ofCharac charac: CBCharacteristic,
                        completion: @escaping UpdateNotificationStateCallback) {
        peripheral.setNotifyValue(toEnabled: enabled,
                                  forCharacWithUUID: charac,
                                  ofServiceWithUUID: charac.service!,
                                  completion: completion)
    }
}

// RSSI
extension Device {
    func notifyRSSI() {
        disableRSSI()
        RSSIUpdateTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true, block: { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            readRSSI()
        })
    }
    
    func disableRSSI() {
        RSSIUpdateTimer?.invalidate()
        RSSIUpdateTimer = nil
    }
    
    private func readRSSI() {
        peripheral.readRSSI { [weak self] result in
            guard let self else { return }
            if case .success(let RSSI) = result {
                if rssi != RSSI {
                    rssi = RSSI
                    NotificationCenter.default.post(name: .DeviceRSSIUpdated, object: nil)
                }
                debugPrint(self.rssi)
            }
        }
    }
}

extension Result where Success == Void {
    static var success: Result { .success(()) }
}
