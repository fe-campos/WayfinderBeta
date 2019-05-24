//
//  ViewController.swift
//  InertialTest
//
//  Created by Reality Room Mac on 5/23/19.
//  Copyright © 2019 Reality Room Mac. All rights reserved.
//

import UIKit
import Dispatch
import CoreLocation
import CoreMotion
import CoreBluetooth

extension Double {
    /** Rounds a double to x places. */
    func roundTo(x : Int) -> Double {
        let divisor = pow(10.0, Double(x))
        return (self * divisor).rounded() / divisor
    }
}

class ViewController: UIViewController, CLLocationManagerDelegate, CBCentralManagerDelegate {
    
    // MARK: UI
    
    @IBOutlet weak var filteredLabel: UILabel!
    @IBOutlet weak var accelFilteredLabel: UILabel!
    @IBOutlet weak var orientationFilteredLabel: UILabel!
    @IBOutlet weak var headingFilteredLabel: UILabel!
    
    @IBOutlet weak var rawDataLabel: UILabel!
    @IBOutlet weak var accelRawLabel: UILabel!
    @IBOutlet weak var gyroRawLabel: UILabel!
    @IBOutlet weak var magRawLabel: UILabel!
    
    // MARK: Initialization
    
    let boseUUID: String = "74874336-B0D5-47A8-078F-DA43BA41B1BB"
    let testUUID: String = "FIXME"
    
    var centralBLEManager: CBCentralManager!
    var beaconManager: CLLocationManager!
    var imuManager: CMMotionManager!
    var activityManager: CMMotionActivityManager!
    var pedometer = CMPedometer()
    var updateTimer: Timer!
    
    let updateFrequency: Double = 10.0

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        rawDataLabel.text = "Pedometer Data"
        accelRawLabel.text = "State: Initializing Pedometer..."
        gyroRawLabel.text = "# Steps: 0"
        magRawLabel.text = "Distance Traveled: 0 m"
        
        beaconManager = CLLocationManager()
        beaconManager.delegate = self
        beaconManager.requestAlwaysAuthorization()
        
        centralBLEManager = CBCentralManager(delegate: self, queue: nil)
        
        imuManager = CMMotionManager()
        imuManager.startAccelerometerUpdates()
        imuManager.startGyroUpdates()
        imuManager.startMagnetometerUpdates()
        imuManager.startDeviceMotionUpdates(using: .xMagneticNorthZVertical)
        
        activityManager = CMMotionActivityManager()
        if CMMotionActivityManager.isActivityAvailable() {
            activityManager.startActivityUpdates(to: OperationQueue.main) {
                [weak self] (activity: CMMotionActivity?) in
                guard let activity = activity else { return }
                DispatchQueue.main.async {
                    if activity.walking {
                        self?.accelRawLabel.text = "State: Walking"
                    } else if activity.stationary {
                        self?.accelRawLabel.text = "State: Stationary"
                    } else if activity.running {
                        self?.accelRawLabel.text = "State: Running"
                    } else if activity.automotive {
                        self?.accelRawLabel.text = "State: Automotive"
                    }
                }
            }
        } else {
            print("Not available.")
        }
        
        if CMPedometer.isStepCountingAvailable() || CMPedometer.isDistanceAvailable() {
            pedometer.startUpdates(from: Date()) {
                [weak self] pedometerData, error in
                guard let pedometerData = pedometerData, error == nil else { return }
                
                DispatchQueue.main.async {
                    self?.gyroRawLabel.text = "Number of Steps Taken: \(pedometerData.numberOfSteps.stringValue)"
                    if let d = pedometerData.distance {
                        self?.magRawLabel.text = "Distance Traveled: \(d.stringValue)"
                    }
                }
            }
        } else {
            print("Steps not available.")
        }
        
        imuManager.accelerometerUpdateInterval = 1.0 / updateFrequency
        imuManager.gyroUpdateInterval = 1.0 / updateFrequency
        imuManager.magnetometerUpdateInterval = 1.0 / updateFrequency
        imuManager.deviceMotionUpdateInterval = 1.0 / updateFrequency
        
        updateTimer = Timer.scheduledTimer(timeInterval: 1.0 / updateFrequency, target: self, selector: #selector(ViewController.imuUpdate), userInfo: nil, repeats: true)
    }
    
    // MARK: IMU Methods
    
    @objc func imuUpdate() {
        let p = 3
        if let accelData = imuManager.accelerometerData {
            // accelRawLabel.text = "Acceleration (g): (\(accelData.acceleration.x.roundTo(x: p)), \(accelData.acceleration.y.roundTo(x: p)), \(accelData.acceleration.z.roundTo(x: p)))"
        }
        if let gyroData = imuManager.gyroData {
            // gyroRawLabel.text = "Rotation Rate (rad/s): (\(gyroData.rotationRate.x.roundTo(x: p)), \(gyroData.rotationRate.y.roundTo(x: p)), \(gyroData.rotationRate.z.roundTo(x: p)))"
        }
        if let magData = imuManager.magnetometerData {
            // magRawLabel.text = "Magnetic Field (uT): (\(magData.magneticField.x.roundTo(x: p)), \(magData.magneticField.y.roundTo(x: p)), \(magData.magneticField.z.roundTo(x: p)))"
        }
        if let deviceMotionData = imuManager.deviceMotion {
            accelFilteredLabel.text = "Acceleration (g): (\(deviceMotionData.userAcceleration.x.roundTo(x: p)), \(deviceMotionData.userAcceleration.y.roundTo(x: p)), \(deviceMotionData.userAcceleration.z.roundTo(x: p)))"
            orientationFilteredLabel.text = "Orientation (rad): (\(deviceMotionData.attitude.roll.roundTo(x: p)), \(deviceMotionData.attitude.pitch.roundTo(x: p)), \(deviceMotionData.attitude.yaw.roundTo(x: p)))"
            headingFilteredLabel.text = "Heading (deg): \(deviceMotionData.heading.roundTo(x: p))"
        }
    }
    
    // MARK: Scanning & Positioning
    
    func startScanning() {
        let uuid = UUID(uuidString: boseUUID)!
        let beaconRegion = CLBeaconRegion(proximityUUID: uuid, identifier: "MyBeacon")
        
        beaconManager.startMonitoring(for: beaconRegion)
        beaconManager.startRangingBeacons(in: beaconRegion)
        
        print("Started ranging for beacon: \(beaconRegion)")
    }
    
    func locationManager(_ manager: CLLocationManager, didRangeBeacons beacons: [CLBeacon], in region: CLBeaconRegion) {
        if beacons.count > 0 {
            updateDistance(beacons[0].proximity)
            print(beacons[0].rssi)
        } else {
            updateDistance(.unknown)
            print(centralBLEManager.retrievePeripherals(withIdentifiers: [UUID(uuidString: boseUUID)!]))
        }
    }
    
    func updateDistance(_ distance: CLProximity) {
        UIView.animate(withDuration: 0.8) {
            switch distance {
            case .unknown:
                self.view.backgroundColor = UIColor.gray
                
            case .far:
                self.view.backgroundColor = UIColor.red
                
            case .near:
                self.view.backgroundColor = UIColor.orange
                
            case .immediate:
                self.view.backgroundColor = UIColor.green
            @unknown default:
                fatalError("CLProximity threw undefined case.")
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if let power = advertisementData[CBAdvertisementDataTxPowerLevelKey] as? Double{
            print("Distance from peripheral: ", pow(10, ((power - Double(truncating: RSSI))/20)))
        }
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        // FIXME: fill in
        print(central.state)
    }
    
    // MARK: Protocol Methods

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedAlways {
            if CLLocationManager.isMonitoringAvailable(for: CLBeaconRegion.self) {
                if CLLocationManager.isRangingAvailable() {
                    startScanning()
                }
            }
        }
    }
}

