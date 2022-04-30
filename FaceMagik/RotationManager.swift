//
//  RotationManager.swift
//  FaceMagik
//
//  Created by Addarsh Chandrasekar on 4/28/22.
//

import CoreMotion

class RotationManager {
    private let motionManager = CMMotionManager()
    private let updateFrequency = 1.0/30.0
    private var motionQueue = OperationQueue()
    
    // Delegate object.
    var rotationManagerDelegate: RotationManagerDelegate?
    
    init(rotationManagerDelegate: RotationManagerDelegate?) {
        self.rotationManagerDelegate = rotationManagerDelegate
    }
    
    // Returns heading updates when the user starts rotating.
    func startRotationUpdates() {
        if !self.motionManager.isDeviceMotionAvailable {
            print ("Device motion unavaible! Error!")
            return
        }
        if self.motionManager.isDeviceMotionActive {
            print ("Skip starting since Motion Manager already started")
            return
        }
        self.motionManager.deviceMotionUpdateInterval = updateFrequency
        self.motionManager.startDeviceMotionUpdates(using: .xMagneticNorthZVertical, to: motionQueue, withHandler: { (data, error) in
            guard let validData = data else {
                return
            }
            self.rotationManagerDelegate?.updatedHeading(heading: Int(validData.heading))
        })
    }
    
    func stopRotationUpdates() {
        if !self.motionManager.isDeviceMotionActive {
            print ("Skip stopping since Motion Manager already inactive")
            return
        }
        self.motionManager.stopDeviceMotionUpdates()
    }
    
    // returns smallest the difference (a-b) in degrees between two angles that are close to each other taking into account roll over from 360 to 0.
    // Can return both positive and negative values.
    static func smallestDegreeDiff(_ a: Int, _ b: Int) -> Int {
        if abs(a-b) > 360 - abs(a-b) {
            // Roll over.
            return a-b >= 0 ? abs(a-b) - 360 : 360 - abs(a-b)
        }
        return a - b
    }
}


