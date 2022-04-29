//
//  FaceContourDetector.swift
//  FaceMagik
//
//  Created by Addarsh Chandrasekar on 3/27/22.
//

import Foundation
import MLKit
import UIKit
import CoreImage.CIFilterBuiltins

class FaceContourDetector {
    
    static let TOTAL_NOSE_BRIDGE_CONTOUR_POINTS = 2
    
    var faceDetector: FaceDetector?
    var faceContourDelegate: FaceContourDelegate?
    
    init(faceContourDelegate: FaceContourDelegate?) {
        self.faceContourDelegate = faceContourDelegate
        
        // Configure detector to find contours.
        let options = FaceDetectorOptions()
        options.performanceMode = .accurate
        options.contourMode = .all
        faceDetector = FaceDetector.faceDetector(options: options)
    }
    
    public func detect(uiImage: UIImage, heading: Int = 0) {
        guard let faceDetector = faceDetector else {
            print ("face detector is not initialized")
            return
        }

        let image = VisionImage(image: uiImage)
        
        faceDetector.process(image) { faces, error in
            
            guard error == nil, let faces = faces else {
                print ("faces array is nil")
                return
            }
            
            if faces.count != 1 {
                print ("Expected 1 face, got \(faces.count) faces")
                return
            }
            
            let face = faces[0]
            guard let noseMiddlePoint = FaceContourDetector.getNoseMiddlePoint(faceContours: face.contours) else {
                print ("Could not get nose middle point")
                return
            }
            guard let faceTillNoseEndContourPoints = FaceContourUtils.getFaceTillNoseEndContourPoints(faceContours: face.contours) else {
                print ("Failed to get face till nose end contour points")
                return
            }
            guard let mouthWithoutLipsContourPoints = FaceContourUtils.getMouthWithoutLipsContourPoints(faceContours: face.contours) else {
                print ("Failed to get mouth without lips contour points")
                return
            }
            guard let mouthWithLipsContourPoints = FaceContourUtils.getMouthWithLipsConoutPoints(faceContours: face.contours) else {
                print ("Failed to get mouth with lips contour points")
                return
            }
            guard let leftEyeContourPoints = FaceContourUtils.getEyeContourPoints(faceContours: face.contours, faceContourType: FaceContourType.leftEye) else {
                print ("Failed to get left eye contour points")
                return
            }
            guard let rightEyeContourPoints = FaceContourUtils.getEyeContourPoints(faceContours: face.contours, faceContourType: FaceContourType.rightEye) else {
                print ("Failed to get right eye contour points")
                return
            }
            guard let leftEyebrowContourPoints = FaceContourUtils.getEyebrowContourPoints(faceContours: face.contours, faceContourTop: FaceContourType.leftEyebrowTop, faceContourBottom: FaceContourType.leftEyebrowBottom) else {
                print ("Failed to get left eyebrow contour points")
                return
            }
            guard let rightEyebrowContourPoints = FaceContourUtils.getEyebrowContourPoints(faceContours: face.contours, faceContourTop: FaceContourType.rightEyebrowTop, faceContourBottom: FaceContourType.rightEyebrowBottom) else {
                print ("Failed to get right eyebrow contour points")
                return
            }
            
            let contourPoints = ContourPoints(noseMiddePoint: noseMiddlePoint, faceTillNoseEndContourPoints: faceTillNoseEndContourPoints, mouthWithoutLipsContourPoints: mouthWithoutLipsContourPoints, mouthWithLipsContourPoints: mouthWithLipsContourPoints, leftEyeContourPoints: leftEyeContourPoints, rightEyeContourPoints: rightEyeContourPoints, leftEyebrowContourPoints: leftEyebrowContourPoints, rightEyebrowContourPoints: rightEyebrowContourPoints)
            self.faceContourDelegate?.detectedContours(uiImage: uiImage, contourPoints: contourPoints, heading: heading)
        }
    }
    
    // Returns middle point of the nose bridge.
    static func getNoseMiddlePoint(faceContours: [FaceContour]) -> [Int]? {
        guard let contour = FaceContourUtils.validateContourType(faceContours: faceContours, faceContourType: FaceContourType.noseBridge) else {
            print ("Failed to validate contour type: noseBridge")
            return nil
        }
        if contour.points.count != TOTAL_NOSE_BRIDGE_CONTOUR_POINTS {
            print ("Expected \(TOTAL_NOSE_BRIDGE_CONTOUR_POINTS) nose bridge contour points, got \(contour.points.count) points")
            return nil
        }
        
        let xSum = contour.points.map{$0.x}.reduce(0, +)
        let ySum = contour.points.map{$0.y}.reduce(0, +)
        let midPoint = [Int(xSum/CGFloat(TOTAL_NOSE_BRIDGE_CONTOUR_POINTS)), Int(ySum/CGFloat(TOTAL_NOSE_BRIDGE_CONTOUR_POINTS))]
        return midPoint
    }
}
