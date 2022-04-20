//
//  FaceMaskDelegate.swift
//  FaceMagik
//
//  Created by Addarsh Chandrasekar on 3/28/22.
//

import Foundation
import CoreImage
import UIKit

protocol FaceMaskDelegate {
    func detectedfaceMask(uiImage: UIImage, faceMask: UIImage, mouthMask: UIImage, leftEyeMask: UIImage, rightEyeMask: UIImage, noseMiddePoint: [Int], faceTillNoseEndContourPoints: [[Int]], mouthWithoutLipsContourPoints: [[Int]], mouthWithLipsContourPoints: [[Int]], leftEyeContourPoints: [[Int]], rightEyeContourPoints: [[Int]], leftEyebrowContourPoints: [[Int]], rightEyebrowContourPoints: [[Int]])
}
