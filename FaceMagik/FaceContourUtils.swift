//
//  FaceContourUtils.swift
//  FaceMagik
//
//  Created by Addarsh Chandrasekar on 4/7/22.
//

import Foundation
import MLKit

class FaceContourUtils {
    
    static let TOTAL_FACE_CONTOUR_POINTS = 36
    
    static func getFaceTillNoseEndContourPoints(faceContours: [FaceContour]) -> [[Int]]? {
        guard let contour = FaceContourUtils.validateContourType(faceContours: faceContours, faceContourType: FaceContourType.face) else {
            print ("Failed to validate contour type: face")
            return nil
        }
        guard let noseBottomContour = FaceContourUtils.validateContourType(faceContours: faceContours, faceContourType: FaceContourType.noseBottom) else {
            print ("Failed to validate contour type: noseBottom")
            return nil
        }
        if contour.points.count != TOTAL_FACE_CONTOUR_POINTS {
            print ("Expected \(TOTAL_FACE_CONTOUR_POINTS) face contour points, got \(contour.points.count) points")
            return nil
        }
        
        // Pick the contour points 26-36, 0-10 from the face. Then pick points 2-0 (in that order) from the nose bottom.
        // This sequence will give us face mask until nose end.
        return toIntegerPoints(visionPoints: Array(contour.points[26...]) + Array(contour.points[0..<11]) + noseBottomContour.points.reversed())
    }
    
    static func getEyeContourPoints(faceContours: [FaceContour], faceContourType: FaceContourType) -> [[Int]]? {
        guard let eye = validateContourType(faceContours: faceContours, faceContourType: faceContourType) else {
            print ("Failed to validate eye contour type: \(faceContourType)")
            return nil
        }
        return toIntegerPoints(visionPoints: eye.points)
    }
    
    static func getEyebrowContourPoints(faceContours: [FaceContour], faceContourTop: FaceContourType, faceContourBottom: FaceContourType) -> [[Int]]? {
        guard let eyebrowTop = validateContourType(faceContours: faceContours, faceContourType: faceContourTop) else {
            print ("Failed to validate eyebrow contour type: \(faceContourTop)")
            return nil
        }
        guard let eyebrowBottom = validateContourType(faceContours: faceContours, faceContourType: faceContourBottom) else {
            print ("Failed to validate eyebrow contour type: \(faceContourBottom)")
            return nil
        }
        return toIntegerPoints(visionPoints: eyebrowTop.points + eyebrowBottom.points.reversed())
    }
    
    
    // Returns an array of contour points of the mouth without lips. These points are in order [Y, X] instead of [X,Y]
    // since that is the preferred ordering for backend.
    static func getMouthWithoutLipsContourPoints(faceContours: [FaceContour]) -> [[Int]]? {
        guard let upperLipBottom = validateContourType(faceContours: faceContours, faceContourType: FaceContourType.upperLipBottom) else {
            print ("Failed to validate upper lip bottom contour type")
            return nil
        }
        
        guard let lowerLipTop = validateContourType(faceContours: faceContours, faceContourType: FaceContourType.lowerLipTop) else {
            print ("Failed to validate contour lower lip top type")
            return nil
        }
        return toIntegerPoints(visionPoints: upperLipBottom.points + lowerLipTop.points)
    }
    
    
    // Returns an array of contour points of the mouth without lips. These points are in order [Y, X] instead of [X,Y]
    // since that is the preferred ordering for backend.
    static func getMouthWithLipsConoutPoints(faceContours: [FaceContour]) -> [[Int]]? {
        guard let upperLipTop = validateContourType(faceContours: faceContours, faceContourType: FaceContourType.upperLipTop) else {
            print ("Failed to validate upper lip top contour type")
            return nil
        }
        
        guard let lowerLipBottom = validateContourType(faceContours: faceContours, faceContourType: FaceContourType.lowerLipBottom) else {
            print ("Failed to validate contour lower lip bottom type")
            return nil
        }
        return toIntegerPoints(visionPoints: upperLipTop.points + lowerLipBottom.points)
    }
    
    // Returns integer points [X,Y] for each VisionPoint.
    static func toIntegerPoints(visionPoints: [VisionPoint]) -> [[Int]] {
        return visionPoints.map { vp in
            return [Int(vp.x), Int(vp.y)]
        }
    }
    
    static func validateContourType(faceContours: [FaceContour], faceContourType: FaceContourType) -> FaceContour? {
        let contours = faceContours.filter({$0.type == faceContourType})
        if contours.count != 1 {
            print ("Expected 1 contour for type: \(faceContourType), got \(contours.count) contours")
            return nil
        }
        return contours[0]
    }
}
