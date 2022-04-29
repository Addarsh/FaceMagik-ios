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
}


