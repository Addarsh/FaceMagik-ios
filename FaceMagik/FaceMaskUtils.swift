//
//  FaceMaskUtils.swift
//  FaceMagik
//
//  Created by Addarsh Chandrasekar on 4/19/22.
//

import Foundation
import MLKit
import CoreImage.CIFilterBuiltins
import UIKit

class FaceMaskUtils {
    
    static let TOTAL_FACE_CONTOUR_POINTS = 36
    
    // Create face mask up to nose end excluding eyes and eyebrows. Skin under the nose will always be excluded.
    // This is to ensure that we don't have to differentiate potential facial hair from skin.
    static func createFaceMaskTillNoseEnd(face: Face, uiImage: UIImage, resizedWidth: Int) -> UIImage? {
        let faceContours = face.contours
        
        guard let faceMaskTillNoseEnd = createFaceMaskTillNoseEnd(faceContours: faceContours, uiImage: uiImage) else {
            print ("Could not create face mask till nose end contour mask")
            return nil
        }
        guard let leftEyeMask = createContourMask(faceContours: faceContours, uiImage: uiImage, faceContourType: FaceContourType.leftEye) else {
            print ("Could not create left eye contour mask")
            return nil
        }
        guard let rightEyeMask = createContourMask(faceContours: faceContours, uiImage: uiImage, faceContourType: FaceContourType.rightEye) else {
            print ("Could not create right eye contour mask")
            return nil
        }
        guard let leftEyebrowMask = createContourMask(faceContours: faceContours, uiImage: uiImage, faceContourOne: FaceContourType.leftEyebrowTop, faceContourTwo: FaceContourType.leftEyebrowBottom, reverse: true) else {
            print ("Could not create left eyebrow mask")
            return nil
        }
        guard let rightEyebrowMask = createContourMask(faceContours: faceContours, uiImage: uiImage, faceContourOne: FaceContourType.rightEyebrowTop, faceContourTwo: FaceContourType.rightEyebrowBottom, reverse: true) else {
            print ("Could not create right eyebrow mask")
            return nil
        }
        var out = bitwiseXor(firstMask: faceMaskTillNoseEnd, secondMask: leftEyeMask)
        out = bitwiseXor(firstMask: out, secondMask: rightEyeMask)
        out = bitwiseXor(firstMask: out, secondMask: leftEyebrowMask)
        out = bitwiseXor(firstMask: out, secondMask: rightEyebrowMask)
        
        guard let ciImage = out else {
            print ("CIImage is nil for face mask till nose end")
            return nil
        }
    
        return Utils.toUIImage(ciImage: ciImage, resizedWidth: resizedWidth)
    }
    
    // Create mouth mask
    static func createMouthMask(face: Face, uiImage: UIImage, resizedWidth: Int) -> UIImage? {
        let faceContours = face.contours
        
        guard let mouthWithoutLipsMask = createContourMask(faceContours: faceContours, uiImage: uiImage, faceContourOne: FaceContourType.upperLipBottom, faceContourTwo: FaceContourType.lowerLipTop, reverse: false) else {
            print ("Could not create mouth without lips mask")
            return nil
        }
        
        return Utils.toUIImage(ciImage: mouthWithoutLipsMask, resizedWidth: resizedWidth)
    }
    
    // Creates a UIImage mask of given contour type.
    static func createContourMask(faceContours: [FaceContour], uiImage: UIImage, faceContourType: FaceContourType, resizedWidth: Int) -> UIImage? {
        guard let contourMask = createContourMask(faceContours: faceContours, uiImage: uiImage, faceContourType: faceContourType) else {
            print ("Could not create contour mask from given countour points")
            return nil
        }
        
        return Utils.toUIImage(ciImage: contourMask, resizedWidth: resizedWidth)
    }
    
    // Creates a CIImage mask of given contour type.
    static func createContourMask(faceContours: [FaceContour], uiImage: UIImage, faceContourType: FaceContourType) -> CIImage? {
        guard let contour = FaceContourUtils.validateContourType(faceContours: faceContours, faceContourType: faceContourType) else {
            print ("Failed to validate contour type: \(faceContourType)")
            return nil
        }
        return createContourMask(uiImage: uiImage, contourPoints: contour.points)
    }
    
    // Creates face mask until nose end. It will include eyes and eyebrows.
    static func createFaceMaskTillNoseEnd(faceContours: [FaceContour], uiImage: UIImage) -> CIImage? {
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
        let contourPoints = Array(contour.points[26...]) + Array(contour.points[0..<11]) + noseBottomContour.points.reversed()
        
        return createContourMask(uiImage: uiImage, contourPoints: contourPoints)
    }
    
    // Creates a face mask without eyes, eyebrows and mouth. This will mostly not be sent to server since it can include beard for men as well.
    // We will instead try to send mask up to the face nose point.
    static func createFaceMask(face: Face, uiImage: UIImage) -> CIImage? {
        let faceContours = face.contours
        
        guard let faceMask = createContourMask(faceContours: faceContours, uiImage: uiImage, faceContourType: FaceContourType.face) else {
            print ("Could not create face contour mask")
            return nil
        }
        guard let leftEyeMask = createContourMask(faceContours: faceContours, uiImage: uiImage, faceContourType: FaceContourType.leftEye) else {
            print ("Could not create left eye contour mask")
            return nil
        }
        guard let rightEyeMask = createContourMask(faceContours: faceContours, uiImage: uiImage, faceContourType: FaceContourType.rightEye) else {
            print ("Could not create right eye contour mask")
            return nil
        }
        guard let leftEyebrowMask = createContourMask(faceContours: faceContours, uiImage: uiImage, faceContourOne: FaceContourType.leftEyebrowTop, faceContourTwo: FaceContourType.leftEyebrowBottom, reverse: true) else {
            print ("Could not create left eyebrow mask")
            return nil
        }
        guard let rightEyebrowMask = createContourMask(faceContours: faceContours, uiImage: uiImage, faceContourOne: FaceContourType.rightEyebrowTop, faceContourTwo: FaceContourType.rightEyebrowBottom, reverse: true) else {
            print ("Could not create right eyebrow mask")
            return nil
        }
        guard let mouthWithLipsMask = createContourMask(faceContours: faceContours, uiImage: uiImage, faceContourOne: FaceContourType.upperLipTop, faceContourTwo: FaceContourType.lowerLipBottom, reverse: false) else {
            print ("Could not create mouth with lips mask")
            return nil
        }
        
        var out = bitwiseXor(firstMask: faceMask, secondMask: leftEyeMask)
        out = bitwiseXor(firstMask: out, secondMask: rightEyeMask)
        out = bitwiseXor(firstMask: out, secondMask: leftEyebrowMask)
        out = bitwiseXor(firstMask: out, secondMask: rightEyebrowMask)
        return bitwiseXor(firstMask: out, secondMask: mouthWithLipsMask)
    }
    
    // Creates a mask combining given two contour types.
    static func createContourMask(faceContours: [FaceContour], uiImage: UIImage, faceContourOne: FaceContourType, faceContourTwo: FaceContourType, reverse: Bool) -> CIImage? {
        guard let contourOne = FaceContourUtils.validateContourType(faceContours: faceContours, faceContourType: faceContourOne) else {
            print ("Failed to validate contour type: \(faceContourOne)")
            return nil
        }
        
        guard let contourTwo = FaceContourUtils.validateContourType(faceContours: faceContours, faceContourType: faceContourTwo) else {
            print ("Failed to validate contour type: \(faceContourTwo)")
            return nil
        }
        let joinedContourPoints = joinContourPoints(firstPoints: contourOne.points, secondPoints: contourTwo.points, reverse: reverse)
        return createContourMask(uiImage: uiImage, contourPoints: joinedContourPoints)
    }
    
    // Returns combined contour points so the resultant list of points is a closed set spanning 360 degrees.
    // Will be used for eyebrows and lips.
    static func joinContourPoints(firstPoints: [VisionPoint], secondPoints: [VisionPoint], reverse: Bool) -> [VisionPoint] {
        if (reverse) {
            return firstPoints + secondPoints.reversed()
        }
        return firstPoints + secondPoints
    }
    
    // Creates a mask of given contour points (in order).
    static func createContourMask(uiImage: UIImage, contourPoints: [VisionPoint]) -> CIImage? {
        guard let width = uiImage.cgImage?.width else {
            print ("Image width is nil")
            return nil
        }
        guard let height = uiImage.cgImage?.height else {
            print ("Image height is nil")
            return nil
        }
        
        // Convert vision points to CGPoints.
        let cgPoints = contourPoints.compactMap({return CGPoint(x: $0.x, y: $0.y)})
        
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format)
        let img = renderer.image { ctx in
            ctx.cgContext.setFillColor(UIColor.black.cgColor)
            ctx.cgContext.fill(CGRect(x: 0, y: 0, width: width, height: height))
            ctx.cgContext.setFillColor(UIColor.white.cgColor)
            ctx.cgContext.addLines(between: cgPoints)
            ctx.cgContext.closePath()
            ctx.cgContext.drawPath(using: .fill)
        }
        guard let cgImage = img.cgImage else {
            print ("face contour cgimage is nil")
            return nil
        }
        return CIImage(cgImage: cgImage)
    }
    
    // bitwiseXor returns a mask that applies the bitwise XOR operation on given masks.
    static func bitwiseXor(firstMask: CIImage?, secondMask: CIImage?) -> CIImage? {
        let comp = CIFilter.differenceBlendMode()
        comp.backgroundImage = firstMask
        comp.inputImage = secondMask
        return comp.outputImage
    }
}
