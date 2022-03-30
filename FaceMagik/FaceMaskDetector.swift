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

class FaceMaskDetector {
    
    var faceDetector: FaceDetector?
    var faceMaskDelegate: FaceMaskDelegate?
    
    init(faceMaskDelegate: FaceMaskDelegate?) {
        self.faceMaskDelegate = faceMaskDelegate
        
        // Configure detector to find contours.
        let options = FaceDetectorOptions()
        options.performanceMode = .accurate
        options.contourMode = .all
        faceDetector = FaceDetector.faceDetector(options: options)
    }
    
    public func detect(uiImage: UIImage) {
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
            guard let ciImage = self.createFaceMask(face: face, uiImage: uiImage) else {
                print ("Could not create Contour mask")
                return
            }
            
            guard let faceMask = UIImage(ciImage: ciImage).resized(toWidth: 720) else {
                print ("UIImage resize failed in face detecor")
                return
            }
            self.faceMaskDelegate?.detectedfaceMask(faceMask: faceMask)
        }
    }
    
    // Creates a face mask without eyes, eyebrows and mouth.
    private func createFaceMask(face: Face, uiImage: UIImage) -> CIImage? {
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
    
    // Creates a mask of given contour type.
    private func createContourMask(faceContours: [FaceContour], uiImage: UIImage, faceContourType: FaceContourType) -> CIImage? {
        guard let contour = validateContourType(faceContours: faceContours, faceContourType: faceContourType) else {
            print ("Failed to validate contour type: \(faceContourType)")
            return nil
        }
        return createContourMask(uiImage: uiImage, contourPoints: contour.points)
    }
    
    // Creates a mask combining given contour types.
    private func createContourMask(faceContours: [FaceContour], uiImage: UIImage, faceContourOne: FaceContourType, faceContourTwo: FaceContourType, reverse: Bool) -> CIImage? {
        guard let contourOne = validateContourType(faceContours: faceContours, faceContourType: faceContourOne) else {
            print ("Failed to validate contour type: \(faceContourOne)")
            return nil
        }
        
        guard let contourTwo = validateContourType(faceContours: faceContours, faceContourType: faceContourTwo) else {
            print ("Failed to validate contour type: \(faceContourTwo)")
            return nil
        }
        let joinedContourPoints = joinContourPoints(firstPoints: contourOne.points, secondPoints: contourTwo.points, reverse: reverse)
        return createContourMask(uiImage: uiImage, contourPoints: joinedContourPoints)
    }
    
    
    // Creates a mask of given contour points (in order).
    private func createContourMask(uiImage: UIImage, contourPoints: [VisionPoint]) -> CIImage? {
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
    
    
    // Returns combined contour points so the resultant list of points is a closed set spanning 360 degrees.
    // Will be used for eyebrows and lips.
    private func joinContourPoints(firstPoints: [VisionPoint], secondPoints: [VisionPoint], reverse: Bool) -> [VisionPoint] {
        if (reverse) {
            return firstPoints + secondPoints.reversed()
        }
        return firstPoints + secondPoints
    }
    
    
    private func validateContourType(faceContours: [FaceContour], faceContourType: FaceContourType) -> FaceContour? {
        let contours = faceContours.filter({$0.type == faceContourType})
        if contours.count != 1 {
            print ("Expected 1 contour for type: \(faceContourType), got \(contours.count) contours")
            return nil
        }
        return contours[0]
    }
    
    // bitwiseXor returns a mask that applies the bitwise XOR operation on given masks.
    private func bitwiseXor(firstMask: CIImage?, secondMask: CIImage?) -> CIImage? {
        let comp = CIFilter.differenceBlendMode()
        comp.backgroundImage = firstMask
        comp.inputImage = secondMask
        return comp.outputImage
    }
    
}
