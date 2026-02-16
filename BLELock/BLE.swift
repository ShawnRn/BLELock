import Foundation
@preconcurrency import CoreBluetooth
import Accelerate

let DeviceInformation = CBUUID(string:"180A")
let ManufacturerName = CBUUID(string:"2A29")
let ModelName = CBUUID(string:"2A24")
let ExposureNotification = CBUUID(string:"FD6F")

func getMACFromUUID(_ uuid: String) -> String? {
    guard let plist = NSDictionary(contentsOfFile: "/Library/Preferences/com.apple.Bluetooth.plist") else { return nil }
    guard let cbcache = plist["CoreBluetoothCache"] as? NSDictionary else { return nil }
    guard let device = cbcache[uuid] as? NSDictionary else { return nil }
    return device["DeviceAddress"] as? String
}

func getNameFromMAC(_ mac: String) -> String? {
    guard let plist = NSDictionary(contentsOfFile: "/Library/Preferences/com.apple.Bluetooth.plist") else { return nil }
    guard let devcache = plist["DeviceCache"] as? NSDictionary else { return nil }
    guard let device = devcache[mac] as? NSDictionary else { return nil }
    if let name = device["Name"] as? String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if trimmed == "" { return nil }
        return trimmed
    }
    return nil
}

@MainActor
class Device: NSObject {
    let uuid : UUID!
    var peripheral : CBPeripheral?
    var manufacture : String?
    var model : String?
    var advData: Data?
    var rssi: Int = 0
    var scanTimer: Timer?
    var macAddr: String?
    var blName: String?
    var localName: String?
    
    override var description: String {
        get {
            if macAddr == nil || blName == nil {
                if let info = getLEDeviceInfoFromUUID(uuid.description) {
                    if let name = info.name { blName = name }
                    if let mac = info.macAddr { macAddr = mac }
                }
            }
            if let pName = peripheral?.name {
                if blName == nil || (blName == "iPhone" || blName == "iPad") {
                    blName = pName
                }
            }
            if macAddr == nil {
                macAddr = getMACFromUUID(uuid.description)
            }
            if let mac = macAddr {
                if blName == nil {
                    blName = getNameFromMAC(mac)
                }
                if let name = blName {
                    if name != "iPhone" && name != "iPad" {
                        return name
                    }
                }
            }
            if let name = localName, name.count > 0, name != "iPhone" && name != "iPad" {
                return name
            }
            if let pName = peripheral?.name, pName.count > 0, pName != "iPhone" && pName != "iPad" {
                return pName
            }
            if let manu = manufacture {
                if let mod = model {
                    if manu == "Apple Inc." && appleDeviceNames[mod] != nil {
                        return appleDeviceNames[mod]!
                    }
                    return String(format: "%@/%@", manu, mod)
                } else {
                    return manu
                }
            }
            if let name = peripheral?.name, name.count > 0 {
                return name
            }
            if let mod = model {
                return mod
            }
            // iBeacon
            if let adv = advData {
                if adv.count >= 25 {
                    var iBeaconPrefix : [uint16] = [0x004c, 0x01502]
                    if adv[0...3] == Data(bytes: &iBeaconPrefix, count: 4) {
                        let major = uint16(adv[20]) << 8 | uint16(adv[21])
                        let minor = uint16(adv[22]) << 8 | uint16(adv[23])
                        let tx = Int8(bitPattern: adv[24])
                        let distance = pow(10, Double(Int(tx) - rssi)/20.0)
                        let d = String(format:"%.1f", distance)
                        return "iBeacon [\(major), \(minor)] \(d)m"
                    }
                }
            }
            if let name = blName {
                return name
            }
            if let mac = macAddr {
                return mac // better than uuid
            }
            return uuid.description
        }
    }

    init(uuid _uuid: UUID) {
        uuid = _uuid
    }
}

@MainActor
protocol BLEDelegate: AnyObject {
    func newDevice(device: Device)
    func updateDevice(device: Device)
    func removeDevice(device: Device)
    func updateRSSI(rssi: Int?, active: Bool)
    func updatePresence(presence: Bool, reason: String)
    func updateCountdown(seconds: Int, reason: String)
    func cancelCountdown(reason: String)
    func bluetoothPowerWarn()
}

@MainActor
class BLE: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    let LOCK_DISABLED = -100
    var centralMgr : CBCentralManager!
    var devices : [UUID : Device] = [:]
    weak var delegate: BLEDelegate?
    var scanMode = false
    var monitoredUUID: UUID?
    var monitoredPeripheral: CBPeripheral?
    var proximityTimer : Timer?
    var signalTimer: Timer?
    var presence = false
    var lockRSSI = -80
    var proximityTimeout = 5.0
    var signalTimeout = 60.0
    var lastReadAt = 0.0
    var powerWarn = true
    var passiveMode = false
    var thresholdRSSI = -70
    var latestRSSIs: [Double] = []
    var latestN: Int = 5
    var activeModeTimer : Timer? = nil
    var connectionTimer : Timer? = nil

    func scanForPeripherals() {
        guard centralMgr.state == .poweredOn else { return }
        guard !centralMgr.isScanning else { return }
        let allowDuplicates = scanMode || passiveMode
        centralMgr.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: allowDuplicates])
    }

    func startScanning() {
        scanMode = true
        scanForPeripherals()
    }

    func stopScanning() {
        scanMode = false
        if activeModeTimer != nil {
            centralMgr.stopScan()
        }
    }

    func setPassiveMode(_ mode: Bool) {
        passiveMode = mode
        if passiveMode {
            activeModeTimer?.invalidate()
            activeModeTimer = nil
            if let p = monitoredPeripheral {
                centralMgr.cancelPeripheralConnection(p)
            }
        }
        scanForPeripherals()
    }

    func startMonitor(uuid: UUID) {
        if let p = monitoredPeripheral {
            centralMgr.cancelPeripheralConnection(p)
        }
        monitoredUUID = uuid
        proximityTimer?.invalidate()
        resetSignalTimer()
        presence = true
        monitoredPeripheral = nil
        activeModeTimer?.invalidate()
        activeModeTimer = nil
        scanForPeripherals()
    }

    var signalCounter: Double = 0
    func resetSignalTimer() {
        signalTimer?.invalidate()
        signalCounter = 0
        
        signalTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true, block: { [weak self] timer in
            guard let self = self else { return }
            MainActor.assumeIsolated {
                self.signalCounter += 1.0
                let remaining = self.signalTimeout - self.signalCounter
                
                if remaining <= 0 {
                    print("Device is lost")
                    self.delegate?.updateRSSI(rssi: nil, active: false)
                    timer.invalidate()
                    self.signalTimer = nil
                    if self.presence {
                        self.presence = false
                        self.delegate?.updatePresence(presence: self.presence, reason: "lost")
                    }
                }
            }
        })
        if let timer = signalTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        MainActor.assumeIsolated {
            switch central.state {
            case .poweredOn:
                print("Bluetooth powered on")
                scanForPeripherals()
                if let uuid = monitoredUUID {
                    startMonitor(uuid: uuid)
                }
                powerWarn = false
            case .poweredOff:
                print("Bluetooth powered off")
                presence = false
                signalTimer?.invalidate()
                signalTimer = nil
                delegate?.cancelCountdown(reason: "lost")
                if powerWarn {
                    powerWarn = false
                    delegate?.bluetoothPowerWarn()
                }
            default:
                break
            }
        }
    }
    
    func getEstimatedRSSI(rssi: Int) -> Int {
        if latestRSSIs.count >= latestN {
            latestRSSIs.removeFirst()
        }
        latestRSSIs.append(Double(rssi))
        var mean: Double = 0.0
        var sddev: Double = 0.0
        vDSP_normalizeD(latestRSSIs, 1, nil, 1, &mean, &sddev, vDSP_Length(latestRSSIs.count))
        return Int(mean)
    }

    var proximityCounter: Double = 0
    func updateMonitoredPeripheral(_ rssi: Int) {
        // print(String(format: "rssi: %d", rssi))
        // Use lockRSSI + 15 as hysteresis for presence detection
        let presenceThreshold = lockRSSI == LOCK_DISABLED ? -65 : (lockRSSI + 15)
        
        if rssi >= presenceThreshold && !presence {
            print("Device is close")
            presence = true
            delegate?.updatePresence(presence: presence, reason: "close")
            latestRSSIs.removeAll() // Avoid bouncing
        }

        let estimatedRSSI = getEstimatedRSSI(rssi: rssi)
        delegate?.updateRSSI(rssi: estimatedRSSI, active: activeModeTimer != nil)

        if estimatedRSSI >= presenceThreshold {
            if let timer = proximityTimer {
                timer.invalidate()
                print("Proximity timer canceled")
                proximityTimer = nil
                delegate?.cancelCountdown(reason: "away")
            }
        } else if presence && proximityTimer == nil && estimatedRSSI < lockRSSI {
            proximityCounter = 0
            proximityTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true, block: { [weak self] timer in
                guard let self = self else { return }
                MainActor.assumeIsolated {
                    self.proximityCounter += 1.0
                    let remaining = self.proximityTimeout - self.proximityCounter
                    
                    if remaining <= 0 {
                        print("Device is away")
                        self.presence = false
                        self.delegate?.updatePresence(presence: self.presence, reason: "away")
                        self.proximityTimer = nil
                        timer.invalidate()
                    } else {
                        // Start notification only after 5 seconds of being away
                        if self.proximityCounter >= 5.0 {
                            self.delegate?.updateCountdown(seconds: Int(remaining), reason: "away")
                        }
                    }
                }
            })
            RunLoop.main.add(proximityTimer!, forMode: .common)
            print("Proximity timer started")
        }
        resetSignalTimer()
    }

    func resetScanTimer(device: Device) {
        device.scanTimer?.invalidate()
        device.scanTimer = Timer.scheduledTimer(withTimeInterval: signalTimeout, repeats: false, block: { _ in
            MainActor.assumeIsolated {
                self.delegate?.removeDevice(device: device)
                if let p = device.peripheral {
                    self.centralMgr.cancelPeripheralConnection(p)
                }
                self.devices.removeValue(forKey: device.uuid)
            }
        })
        if let timer = device.scanTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    func connectMonitoredPeripheral() {
        guard let p = monitoredPeripheral else { return }

        guard p.state == .disconnected && centralMgr.state == .poweredOn else { return }
        print("Connecting")
        centralMgr.connect(p, options: nil)
        connectionTimer?.invalidate()
        let uuid = p.identifier
        connectionTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: false, block: { _ in
            MainActor.assumeIsolated {
                if let p = self.centralMgr.retrievePeripherals(withIdentifiers: [uuid]).first {
                    if p.state == .connecting {
                        print("Connection timeout")
                        self.centralMgr.cancelPeripheralConnection(p)
                    }
                }
            }
        })
        RunLoop.main.add(connectionTimer!, forMode: .common)
    }

    //MARK:- CBCentralManagerDelegate start

    nonisolated func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any],
                        rssi RSSI: NSNumber)
    {
        MainActor.assumeIsolated {
            let rssi = RSSI.intValue > 0 ? 0 : RSSI.intValue
            if let uuid = monitoredUUID {
                if peripheral.identifier.description == uuid.description {
                    if monitoredPeripheral == nil {
                        monitoredPeripheral = peripheral
                    }
                    if activeModeTimer == nil {
                        //print("Discover \(rssi)dBm")
                        updateMonitoredPeripheral(rssi)
                        if !passiveMode {
                            connectMonitoredPeripheral()
                        }
                    }
                }
            }

            if (scanMode) {
                if let uuids = advertisementData["kCBAdvDataServiceUUIDs"] as? [CBUUID] {
                    for uuid in uuids {
                        if uuid == ExposureNotification {
                            //print("Device \(peripheral.identifier) Exposure Notification")
                            return
                        }
                    }
                }
                let dev = devices[peripheral.identifier]
                var device: Device
                if (dev == nil) {
                    device = Device(uuid: peripheral.identifier)
                    if (rssi >= thresholdRSSI) {
                        device.peripheral = peripheral
                        device.rssi = rssi
                        device.advData = advertisementData["kCBAdvDataManufacturerData"] as? Data
                        if let lName = advertisementData["kCBAdvDataLocalName"] as? String {
                            device.localName = lName
                        }
                        devices[peripheral.identifier] = device
                        central.connect(peripheral, options: nil)
                        delegate?.newDevice(device: device)
                    }
                } else {
                    device = dev!
                    device.rssi = rssi
                    delegate?.updateDevice(device: device)
                }
                resetScanTimer(device: device)
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager,
                        didConnect peripheral: CBPeripheral)
    {
        MainActor.assumeIsolated {
            peripheral.delegate = self
            if scanMode {
                peripheral.discoverServices([DeviceInformation])
            }
            if peripheral == monitoredPeripheral && !passiveMode {
                print("Connected")
                connectionTimer?.invalidate()
                connectionTimer = nil
                peripheral.readRSSI()
            }
        }
    }

    //MARK:CBCentralManagerDelegate end -
    
    //MARK:- CBPeripheralDelegate start

    nonisolated func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        MainActor.assumeIsolated {
            guard peripheral == monitoredPeripheral else { return }
            let rssi = RSSI.intValue > 0 ? 0 : RSSI.intValue
            //print("readRSSI \(rssi)dBm")
            updateMonitoredPeripheral(rssi)
            lastReadAt = Date().timeIntervalSince1970

            if activeModeTimer == nil && !passiveMode {
                print("Entering active mode")
                if !scanMode {
                    centralMgr.stopScan()
                }
                let uuid = peripheral.identifier
                activeModeTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true, block: { _ in
                    MainActor.assumeIsolated {
                        guard let peripheral = self.centralMgr.retrievePeripherals(withIdentifiers: [uuid]).first else { return }
                        if Date().timeIntervalSince1970 > self.lastReadAt + 10 {
                            print("Falling back to passive mode")
                            self.centralMgr.cancelPeripheralConnection(peripheral)
                            self.activeModeTimer?.invalidate()
                            self.activeModeTimer = nil
                            self.scanForPeripherals()
                        } else if peripheral.state == .connected {
                            peripheral.readRSSI()
                        } else {
                            self.connectMonitoredPeripheral()
                        }
                    }
                })
                RunLoop.main.add(activeModeTimer!, forMode: .common)
            }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverServices error: Error?) {
        MainActor.assumeIsolated {
            if let services = peripheral.services {
                for service in services {
                    if service.uuid == DeviceInformation {
                        peripheral.discoverCharacteristics([ManufacturerName, ModelName], for: service)
                    }
                }
            }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?)
    {
        MainActor.assumeIsolated {
            if let chars = service.characteristics {
                for chara in chars {
                    if chara.uuid == ManufacturerName || chara.uuid == ModelName {
                        peripheral.readValue(for:chara)
                    }
                }
            }
        }
    }
    
    nonisolated func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?)
    {
        MainActor.assumeIsolated {
            if let value = characteristic.value {
                let str: String? = String(data: value, encoding: .utf8)
                if let s = str {
                    if let device = devices[peripheral.identifier] {
                        if characteristic.uuid == ManufacturerName {
                            device.manufacture = s
                            delegate?.updateDevice(device: device)
                        }
                        if characteristic.uuid == ModelName {
                            device.model = s
                            delegate?.updateDevice(device: device)
                        }
                        if device.model != nil && device.model != nil && device.peripheral != monitoredPeripheral {
                            centralMgr.cancelPeripheralConnection(peripheral)
                        }
                    }
                }
            }
        }
    }
    
    nonisolated func peripheral(_ peripheral: CBPeripheral,
                    didModifyServices invalidatedServices: [CBService])
    {
        MainActor.assumeIsolated {
            peripheral.discoverServices([DeviceInformation])
        }
    }
    //MARK:CBPeripheralDelegate end -

    override init() {
        super.init()
        centralMgr = CBCentralManager(delegate: self, queue: nil)
    }
}
