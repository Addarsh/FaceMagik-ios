//
//  FaceContourDetector.swift
//  FaceMagik
//
//  Created by Addarsh Chandrasekar on 3/27/22.
//

import Foundation
import MLKit
import UIKit

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
            
            let faceContours = face.contours.filter({$0.type == FaceContourType.face})
            if faceContours.count != 1 {
                print ("Expected 1 face contour, got \(faceContours.count) contours")
                return
            }
            
            let contourPoints = faceContours[0].points
            guard let ciImage = self.createContourMask(uiImage: uiImage, contourPoints: contourPoints) else {
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
    
    
}
