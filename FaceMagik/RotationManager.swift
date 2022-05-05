//
//  RotationManager.swift
//  FaceMagik
//
//  Created by Addarsh Chandrasekar on 4/28/22.
//

import CoreMotion
import UIKit

class RotationManager {
    enum Direction {
        case CLOCKWISE
        case COUNTER_CLOCKWISE
    }
    
    private let motionManager = CMMotionManager()
    private let updateFrequency = 1.0/30.0
    private var motionQueue = OperationQueue()
    
    // Rotation mode variables.
    // Initial heading valye observed when the Motion Manager is started.
    private var initialHeading: Int = -1
    // Heading values (0-360) encountered during rotation.
    private var headingSet: Set<Int> = []
    private var numHeadingValuesSeen: Int = 0
    
    // Navigation mode variables.
    private var prevNavHeading: Int = -1
    private var prevDegreesDiff: Int = 360
    
    
    init() {
        if !self.motionManager.isDeviceMotionAvailable {
            print ("Device motion unavaible! Error!")
            return
        }
        if self.motionManager.isDeviceMotionActive {
            print ("Skip starting since Motion Manager already started")
            return
        }
        self.motionManager.deviceMotionUpdateInterval = updateFrequency

    }
    
    // Returns heading updates when the user is in rotation mode.
    func startRotationUpdates(rotationManagerDelegate: RotationManagerDelegate?) {
        self.motionManager.startDeviceMotionUpdates(using: .xMagneticNorthZVertical, to: motionQueue, withHandler: { (data, error) in
            guard let validData = data else {
                return
            }
            let heading = Int(validData.heading)
            if (self.initialHeading) == -1 {
                self.initialHeading = heading
            }
            self.headingSet.insert(heading)
            rotationManagerDelegate?.updatedHeading(heading: Int(validData.heading))
            
            self.checkIfRotationIsComplete(rotationManagerDelegate: rotationManagerDelegate)
        })
    }
    
    // Navigates user to given target heading.
    func navigateUserToHeading(navigateUserDelegate: NavigateUserDelegate, targetHeading: Int) {
        self.motionManager.startDeviceMotionUpdates(using: .xMagneticNorthZVertical, to: motionQueue, withHandler: { (data, error) in
            guard let validData = data else {
                return
            }
            let heading = Int(validData.heading)
            navigateUserDelegate.updatedHeadingValues(heading: heading)
            
            let smallestDegreeDiff = RotationManager.smallestDegreeDiff(targetHeading, heading)
            if (abs(smallestDegreeDiff) <= 10) {
                // User has reached target heading.
                navigateUserDelegate.stopRotation()
                return
            }
            var navigationDirection: Direction = Direction.CLOCKWISE
            if (smallestDegreeDiff < 0) {
                navigationDirection = Direction.COUNTER_CLOCKWISE
            }
            navigateUserDelegate.startRotation(direction: navigationDirection, deltaDegrees: abs(smallestDegreeDiff))
        })
    }
    
    // Stop updates from motion manager.
    func stopRotationUpdates() {
        if !self.motionManager.isDeviceMotionActive {
            print ("Skip stopping since Motion Manager already inactive")
            return
        }
        self.motionManager.stopDeviceMotionUpdates()
    }
    
    
    private func checkIfRotationIsComplete(rotationManagerDelegate: RotationManagerDelegate?) {
        // Ensure that each quadrant (0-90, 90-180, 180-270, 270-360) has enough heading density.
        let sortedHeadings = Array(headingSet).sorted()
        var headingBuckets: [[Int]] = [[], [], [], []]
        for heading in sortedHeadings {
            let quadrant = Int(heading / 90)
            if (quadrant > 3) {
                // Shouldn't happen but a safeguard in case 360 is a valid heading value.
                continue
            }
            headingBuckets[quadrant].append(heading)
        }
        for bucket in headingBuckets {
            if (bucket.count < 50) {
                // Too few points in quadrant.
                return
            }
            let range = bucket.last! - bucket.first!
            if (range < 70) {
                // Range covered is too less.
                return
            }
        }
        rotationManagerDelegate?.oneRotationComplete()
        self.stopRotationUpdates()
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


