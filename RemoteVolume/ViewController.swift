//
//  ViewController.swift
//  RemoteVolume
//
//  Created by toshiyuki on 2015/12/22.
//  Copyright © 2015年 toshiyuki. All rights reserved.
//

import UIKit
import CoreBluetooth

class ViewController : UIViewController, UITableViewDelegate, UITableViewDataSource, CBCentralManagerDelegate {
    
    @IBOutlet weak var tableView: UITableView!
    var refreshControl:UIRefreshControl?
    
    var manager: CBCentralManager?
    var list: [Connection] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.dataSource = self
        tableView.delegate = self
        
        self.refreshControl = UIRefreshControl()
        self.refreshControl!.attributedTitle = NSAttributedString(string: "更新")
        self.refreshControl!.addTarget(self, action: "refresh", forControlEvents: UIControlEvents.ValueChanged)
        self.tableView.addSubview(refreshControl!)
        
        manager = CBCentralManager(delegate: self, queue: nil)
    }
    
    override func viewDidDisappear(animated: Bool) {
        for c in list {
            manager?.cancelPeripheralConnection(c.peripheral!)
        }
        list = []
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func refresh() {
        for c in list {
            manager?.cancelPeripheralConnection(c.peripheral!)
        }
        list = []
        manager?.scanForPeripheralsWithServices([Peripheral.SERVICE_UUID], options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: true
        ])
        tableView.reloadData()
        self.refreshControl!.endRefreshing()
    }
    
    // ####################################################################
    // UITableViewDelegate
    // ####################################################################

    
    // ####################################################################
    // UITableViewDataSource
    // ####################################################################

    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return list.count;
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let c = list[indexPath.row]
        let cell = tableView.dequeueReusableCellWithIdentifier("cell")
        let label = cell?.viewWithTag(1) as! UILabel
        let slider = cell?.viewWithTag(2) as! UISlider
        label.text = c.name
        slider.value = Float(c.value)
        slider.addTarget(c, action: "changeValue:", forControlEvents: UIControlEvents.ValueChanged)
        slider.enabled = true
        if c.requestingName || c.requestingCurrentVolume {
            slider.enabled = false
        }
        return cell!
    }
    
    // ####################################################################
    // CBCentralManagerDelegate
    // ####################################################################
    func centralManagerDidUpdateState(central: CBCentralManager) {
        if central.state == CBCentralManagerState.PoweredOn {
            manager?.scanForPeripheralsWithServices([Peripheral.SERVICE_UUID], options: [
                CBCentralManagerScanOptionAllowDuplicatesKey: false
            ])
        }
        if central.state == CBCentralManagerState.PoweredOff {
            manager?.stopScan()
        }
    }
    
    func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : AnyObject], RSSI: NSNumber) {
        
        for cc in list {
            if cc.peripheral == peripheral {
                return;
            }
        }
        
        let c = Connection()
        c.name = "connecting..."
        c.peripheral = peripheral
        list.append(c)
        c.tableView = tableView;
        c.connect(central)
        tableView.reloadData()
    }
    
    func centralManager(central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {
        for c in list {
            if c.peripheral == peripheral {
                c.peripheral?.discoverServices([Peripheral.SERVICE_UUID])
            }
        }
    }
    
    // ####################################################################
    // Connection
    // ####################################################################
    class Connection : NSObject, CBPeripheralDelegate {
        override init() {
            super.init()
        }
        var name : String = ""
        var peripheral : CBPeripheral?
        var txCaracteristic : CBCharacteristic?
        var rxCaracteristic : CBCharacteristic?
        var value : Double = 0.0
        var tableView : UITableView?
        var requestingName = false
        var requestingCurrentVolume = true
        
        func connect(central: CBCentralManager) {
            peripheral?.delegate = self
            central.connectPeripheral(peripheral!, options: [
                CBConnectPeripheralOptionNotifyOnDisconnectionKey: true
            ])
        }
        
        func toByteArray<T>(var value: T) -> [UInt8] {
            return withUnsafePointer(&value) {
                Array(UnsafeBufferPointer(start: UnsafePointer<UInt8>($0), count: sizeof(T)))
            }
        }
        
        func requestName() {
            print("RequestName")
            requestingName = true
            request(Peripheral.REQUEST_NAME)
        }
        
        func requestCurrentVolume() {
            print("RequestCurrentVolume")
            requestingCurrentVolume = true
            request(Peripheral.REQUEST_VOLUME)
        }
        
        func request(code: String) {
            let d = NSMutableData()
            var bytes = [UInt8]()
            for char in code.utf8 {
                bytes += [char]
            }
            d.appendBytes(bytes, length: bytes.count)
            peripheral?.writeValue(d, forCharacteristic: txCaracteristic!, type: CBCharacteristicWriteType.WithoutResponse)
        }
        
        func set(val: Double) {
            value = val
            let d = NSMutableData()
            let f = toByteArray(value)
            d.appendBytes(f, length: f.count)
            peripheral?.writeValue(d, forCharacteristic: txCaracteristic!, type: CBCharacteristicWriteType.WithoutResponse)
        }
        
        func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
            for service in self.peripheral!.services! {
                self.peripheral?.discoverCharacteristics([Peripheral.RX_CHARA, Peripheral.TX_CHARA], forService: service)
            }
        }
  
        func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {
            for c in service.characteristics! {
                if c.UUID.UUIDString == Peripheral.TX_CHARA.UUIDString {
                    txCaracteristic = c
                }
                if c.UUID.UUIDString == Peripheral.RX_CHARA.UUIDString {
                    rxCaracteristic = c
                }
            }
            if txCaracteristic != nil && rxCaracteristic != nil {
                self.peripheral?.setNotifyValue(true, forCharacteristic: self.rxCaracteristic!)
                requestName()
            }
        }
        
        func peripheral(peripheral: CBPeripheral, didWriteValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
            let data = characteristic.value
            print("Write: %@", data)
        }
        
        func peripheral(peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
            let data = characteristic.value
            print("Update: %@", data)
            if (requestingName) {
                requestingName = false
                let str = NSString(data:data!, encoding:NSUTF8StringEncoding)
                if str != nil {
                    name = str as! String
                    requestCurrentVolume()
                } else {
                    requestName()
                }
                return
            }
            requestingCurrentVolume = false
            value = UnsafePointer<Double>(data!.bytes).memory
            print("Update Value: %@", value)
            dispatch_async_main {
                self.tableView?.reloadData()
            }
        }

        func dispatch_async_main(block: () -> ()) {
            dispatch_async(dispatch_get_main_queue(), block)
        }
        
        func changeValue(sender : UISlider) {
            set(Double(sender.value))
        }
    }
}

