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
    
    static func createAlert(message: String) -> UIAlertController {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)

        let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.style = UIActivityIndicatorView.Style.medium
        loadingIndicator.startAnimating();

        alert.view.addSubview(loadingIndicator)
        return alert
    }
    
    static func toUIImage(ciImage: CIImage, resizedWidth: Int) -> UIImage? {
       return UIImage(ciImage: ciImage).resized(toWidth: CGFloat(resizedWidth))
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
