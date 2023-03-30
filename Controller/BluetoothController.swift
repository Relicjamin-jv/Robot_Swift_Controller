//
//  BluetoothVM.swift
//  BluetoothMessageSenderPI
//
//  Created by Collin Campbell on 2/19/23.
//

import Foundation
import CoreBluetooth
import UIKit

class BluetoothVM: NSObject, ObservableObject, CBPeripheralDelegate {
    var connected: Bool = false
    var debug: UILabel!
    
    // Predefined
    private var centralManager: CBCentralManager?
    private let definedService = CBUUID(string: "0000181c-0000-1000-8000-00805f9b34fb")
    private let definedCharacterisic = CBUUID(string: "00002a37-0000-1000-8000-00805f9b34fb")
    
    // Information about connection
    private var discoveredPeripheral: CBPeripheral?
    private var discoverdCharateristic: CBCharacteristic?
    
    
    init(debug: UILabel){
        super.init()
        self.centralManager = CBCentralManager(delegate: self, queue: .main)
        self.debug = debug
        print("Started")
    }

    
    func sendData(data: [UInt8]){
        guard let p = discoveredPeripheral else {
            self.debug.text = "Failed: No Peripheral"
            print("No devices found")
            return
        }
        guard let c = discoverdCharateristic else {
            self.debug.text = "Failed: No Characteristic"
            print("No characteristics found")
            return
        }
        let bytes = Data(bytes: data, count: data.count)
        p.writeValue(bytes, for: c, type: CBCharacteristicWriteType.withResponse)
    }
    
}

extension BluetoothVM: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("Power on")
        if central.state == .poweredOn {
            print("Scanning")
            self.debug.text = "Scanning"
            self.centralManager?.scanForPeripherals(withServices: [definedService])
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        discoveredPeripheral = peripheral // This is the device that we want
        
        if discoveredPeripheral != nil{
            let device = discoveredPeripheral!
            device.delegate = self
            centralManager?.connect(device)
            connected = true
            self.debug.text = "Connected to device"
            print("connection made")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        self.debug.text = "Scanning for Services"
        print("Scanning for services")
        peripheral.discoverServices([definedService])
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if error != nil{
            self.debug.text = "No services found for peripheral"
            print("No services found")
            return
        }
        guard let services = peripheral.services else{
            return
        }
        
        for service in services{
            peripheral.discoverCharacteristics([definedCharacterisic], for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else {
            return
        }
        self.debug.text = "Discovering characteristics"
        print("Discovering")
        for characteristic in characteristics {
            if characteristic.uuid.isEqual(definedCharacterisic){
                let writeCharacteristic = characteristic
                discoverdCharateristic = characteristic
                self.debug.text = "Connected"
                print("Connected")
            }
        }
    }
}

