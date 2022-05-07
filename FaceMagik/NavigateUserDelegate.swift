//
//  NavigateUserDelegate.swift
//  FaceMagik
//
//  Created by Addarsh Chandrasekar on 5/1/22.
//

protocol NavigateUserDelegate {
    func updatedHeadingValues(heading: Int)
    func startRotation(direction: RotationManager.Direction, deltaDegrees: Int)
    func targetHeadingReached()
    func navigationComplete()
}

