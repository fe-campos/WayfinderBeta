//
//  ViewController.swift
//  InertialTest
//
//  Created by Reality Room Mac on 5/23/19.
//  Copyright © 2019 Reality Room Mac. All rights reserved.
//

import UIKit
import MessageUI
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

class ViewController: UIViewController, CLLocationManagerDelegate, MFMailComposeViewControllerDelegate {
    
    // MARK: UI
    
    @IBOutlet weak var filteredLabel: UILabel!
    @IBOutlet weak var accelFilteredLabel: UILabel!
    @IBOutlet weak var orientationFilteredLabel: UILabel!
    @IBOutlet weak var headingFilteredLabel: UILabel!
    
    @IBOutlet weak var rawDataLabel: UILabel!
    @IBOutlet weak var accelRawLabel: UILabel!
    @IBOutlet weak var gyroRawLabel: UILabel!
    @IBOutlet weak var magRawLabel: UILabel!
    
    @IBOutlet weak var stateButton: UIButton!
    
    // MARK: Initialization
    
    var imuManager: CMMotionManager!
    var locationManager: CLLocationManager!
    var activityManager: CMMotionActivityManager!
    var pedometer = CMPedometer()
    var updateTimer: Timer!
    
    let updateFrequency: Double = 50.0
    
    var motionData: String = "t, ax, ay, az, rx, ry, rz, r, p, y, steps, distance\n"
    var initTime: Date = Date()
    
    var state: Bool = false
    
    var hitCount: Int = 7
    var hitTime: Date = Date()
    var numSteps: Int = 0
    var distance: Double = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        rawDataLabel.text = "Pedometer Data"
        accelRawLabel.text = "State: Initializing Pedometer..."
        gyroRawLabel.text = "# Steps: 0"
        magRawLabel.text = "Distance Traveled: 0 m"
        
        locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.requestAlwaysAuthorization()
        
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
        
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
                    self?.numSteps = pedometerData.numberOfSteps.intValue
                    self?.gyroRawLabel.text = "Number of Steps Taken: \(pedometerData.numberOfSteps.stringValue)"
                    if let d = pedometerData.distance {
                        self?.distance = d.doubleValue
                        self?.magRawLabel.text = "Distance Traveled: \(d.stringValue)"
                    }
                }
            }
        } else {
            print("Steps not available.")
        }
        
        initTime = Date()
        
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
            
            if (state) {
                let datastr = "\(Date().timeIntervalSince(initTime)), \(deviceMotionData.userAcceleration.x), \(deviceMotionData.userAcceleration.y), \(deviceMotionData.userAcceleration.z), \(deviceMotionData.rotationRate.x), \(deviceMotionData.rotationRate.y), \(deviceMotionData.rotationRate.z), \(deviceMotionData.attitude.roll), \(deviceMotionData.attitude.pitch), \(deviceMotionData.attitude.yaw), \(numSteps), \(distance)\n"
                
                motionData.append(datastr)
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        // imuUpdate()
    }
    
    // Recording
    
    @IBAction func stateButtonHit(_ sender: Any) {
        state = !state
        if (!state) {
            let curr: Date = Date()
            if (curr.timeIntervalSince(hitTime) < 0.25) {
                hitCount -= 1
            } else {
                hitCount = 10
            }
            hitTime = curr
            state = !state
            if (hitCount == 0) {
                state = !state
                stateButton.setTitle("Run", for: .normal)
                // write string
                print(motionData)
                let file = "imuData.txt"
                if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                    let fileURL = dir.appendingPathComponent(file)
                    do {
                        try motionData.write(to: fileURL, atomically: false, encoding: .utf8)
                        sendEmail(url: fileURL)
                    } catch {
                        /* error handling here */
                        print("Write failed.")
                    }
                }
            }
        } else {
            stateButton.setTitle("Save", for: .normal)
        }
    }
    
    
    func sendEmail(url: URL) {
        if MFMailComposeViewController.canSendMail() {
            print("sending mail")
            let mailComposer = MFMailComposeViewController()
            mailComposer.setSubject("IMU Data")
            mailComposer.setMessageBody("Attached as a text file.", isHTML: false)
            mailComposer.setToRecipients(["Arijit.Chatterjee@microsoft.com"])
            print("ok")
            
            do {
                let attachmentData = try Data(contentsOf: url)
                mailComposer.addAttachmentData(attachmentData, mimeType: "text/plain", fileName: "imuData")
                mailComposer.mailComposeDelegate = self
                self.present(mailComposer, animated: true, completion: nil)
            } catch let error {
                print("We have encountered error \(error.localizedDescription)")
            }
            
        } else {
            print("Email is not configured in settings app or we are not able to send an email")
        }
    }
    
    //MARK:- MailcomposerDelegate
    
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        switch result {
        case .cancelled:
            print("User cancelled")
            break
            
        case .saved:
            print("Mail is saved by user")
            break
            
        case .sent:
            print("Mail is sent successfully")
            break
            
        case .failed:
            print("Sending mail is failed")
            break
        default:
            break
        }
        
        controller.dismiss(animated: true)
    }
}

