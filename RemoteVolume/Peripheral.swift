//
//  Peripheral.swift
//  RemoteVolume
//
//  Created by toshiyuki on 2015/12/22.
//  Copyright © 2015年 toshiyuki. All rights reserved.
//

import UIKit
import CoreBluetooth

class Peripheral : NSObject, CBPeripheralManagerDelegate {

    static let SERVICE_UUID = CBUUID(string: "75c80a3d-e77b-490d-9f91-2f1e8c673f4c")
    static let TX_CHARA = CBUUID(string: "410d77c1-e245-40a5-b158-0e6df5d8c468")
    static let RX_CHARA = CBUUID(string: "6a5bc60f-623d-48d4-870c-37742f76475a")
    static let REQUEST_NAME = "REQ_NAME";
    static let REQUEST_VOLUME = "REQ_VOLUME";

    class var sharedInstance : Peripheral {
        struct Static {
            static let instance = Peripheral()
        }
        return Static.instance
    }
    
    var manager: CBPeripheralManager?
    var service : CBMutableService?
    var txCharacteristic: CBMutableCharacteristic? // WRITE|WRITE_WITHOUT_RESPONSE
    var rxCharacteristic: CBMutableCharacteristic? // NOTIFY

    override init() {
        super.init();
        manager = CBPeripheralManager(delegate: self, queue: nil)
    }
    
    func startAdvertising() {
        txCharacteristic = CBMutableCharacteristic(
            type: Peripheral.TX_CHARA,
            properties: CBCharacteristicProperties.Write.union(CBCharacteristicProperties.WriteWithoutResponse),
            value: nil,
            permissions: CBAttributePermissions.Writeable
        )
        
        rxCharacteristic = CBMutableCharacteristic(
            type: Peripheral.RX_CHARA,
            properties: CBCharacteristicProperties.Notify,
            value: nil,
            permissions: CBAttributePermissions.Readable
        )
        
        service = CBMutableService(type: Peripheral.SERVICE_UUID, primary: true)
        
        service!.characteristics = [txCharacteristic!, rxCharacteristic!]
        
        manager?.addService(service!)
        
        manager?.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [Peripheral.SERVICE_UUID],
            CBAdvertisementDataLocalNameKey: UIDevice.currentDevice().name
        ])
    }
    
    func peripheralManagerDidUpdateState(peripheral: CBPeripheralManager) {
        if peripheral.state == CBPeripheralManagerState.PoweredOn {
            startAdvertising()
        }
        if peripheral.state == CBPeripheralManagerState.PoweredOff {
            manager?.stopAdvertising()
        }
    }
    
    func toByteArray<T>(var value: T) -> [UInt8] {
        return withUnsafePointer(&value) {
            Array(UnsafeBufferPointer(start: UnsafePointer<UInt8>($0), count: sizeof(T)))
        }
    }
    
    func peripheralManager(peripheral: CBPeripheralManager, central: CBCentral, didSubscribeToCharacteristic characteristic: CBCharacteristic) {
    }
    
    func peripheralManager(peripheral: CBPeripheralManager, didReceiveWriteRequests requests: [CBATTRequest]) {
        
        let data = requests[0].value
        let dataStr: NSString? = NSString(data:data!, encoding:NSUTF8StringEncoding)
        print("Receive: %@", dataStr)
        
        
        if (dataStr == Peripheral.REQUEST_NAME) {
            let d = NSMutableData()
            var bytes = [UInt8]()
            for char in UIDevice.currentDevice().name.utf8{
                bytes += [char]
            }
            d.appendBytes(bytes, length: bytes.count)
            let ok = peripheral.updateValue(d, forCharacteristic: rxCharacteristic!, onSubscribedCentrals: nil)
            print("Send REQUEST_NAME: %@", ok)
        } else if (dataStr == Peripheral.REQUEST_VOLUME) {
            let d = NSMutableData()
            let f = toByteArray(Volume.get())
            d.appendBytes(f, length: f.count)
            let ok = peripheral.updateValue(d, forCharacteristic: rxCharacteristic!, onSubscribedCentrals: nil)
            print("Send REQUEST_VOLUME: %@", ok)
        } else {
            let v = UnsafePointer<Double>(data!.bytes).memory
            Volume.set(v)
        }
    }
    
    func peripheralManagerDidStartAdvertising(peripheral: CBPeripheralManager, error: NSError?) {
        print("ERR: %@", error)
    }
}