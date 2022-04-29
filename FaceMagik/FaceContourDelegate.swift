//
//  FaceMaskDelegate.swift
//  FaceMagik
//
//  Created by Addarsh Chandrasekar on 3/28/22.
//

import Foundation
import CoreImage
import UIKit

struct ContourPoints {
    let noseMiddePoint: [Int]
    let faceTillNoseEndContourPoints: [[Int]]
    let mouthWithoutLipsContourPoints: [[Int]]
    let mouthWithLipsContourPoints: [[Int]]
    let leftEyeContourPoints: [[Int]]
    let rightEyeContourPoints: [[Int]]
    let leftEyebrowContourPoints: [[Int]]
    let rightEyebrowContourPoints: [[Int]]
}

protocol FaceContourDelegate {
    func detectedContours(uiImage: UIImage, contourPoints: ContourPoints, heading: Int)
}
