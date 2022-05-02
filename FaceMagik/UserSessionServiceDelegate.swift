//
//  UserSessionServiceDelegate.swift
//  FaceMagik
//
//  Created by Addarsh Chandrasekar on 4/28/22.
//

protocol UserSessionServiceDelegate {
    func onSessionCreation(userSessionId: String)
    func uploadRotationImageResponseReceived()
    func primaryHeadingDirection(heading: Int)
}

