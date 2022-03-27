//
//  Utils.swift
//  FaceMagik
//
//  Created by Addarsh Chandrasekar on 3/26/22.
//

import UIKit

class Utils {
    
    // Returns a base64 encoded string representation of given UIImage.
    // If no data is present in image, returns an empty string.
    static func tobase64String(uiImage: UIImage) -> String {
        guard let pngData = uiImage.jpegData(compressionQuality: 0.8) else {
            print ("Could not convert CIImage to Data")
            return ""
        }
        return pngData.base64EncodedString(options: .endLineWithCarriageReturn)
    }
}

extension UIImage {
    func resized(toWidth width: CGFloat) -> UIImage? {
        let canvasSize = CGSize(width: width, height: CGFloat(ceil(width/size.width * size.height)))
        UIGraphicsBeginImageContextWithOptions(canvasSize, false, scale)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(origin: .zero, size: canvasSize))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}
