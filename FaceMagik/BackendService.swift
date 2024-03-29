//
//  BackendService.swift
//  FaceMagik
//
//  Created by Addarsh Chandrasekar on 3/24/22.
//
import Foundation
import CoreImage
import UIKit

class BackendService {
    struct SessionCreationResponse: Codable {
        let message: String
        let session_id: String
    }
    
    struct SkinToneDetectionRequest: Codable {
        let session_id: String
        let image_name: String
        // Image is a Base64 encoded string.
        let image: String
        let nose_middle_point: [Int]
        let face_till_nose_end_contour_points: [[Int]]
        let mouth_without_lips_contour_points: [[Int]]
        let mouth_with_lips_contour_points: [[Int]]
        let left_eye_contour_points: [[Int]]
        let right_eye_contour_points: [[Int]]
        let left_eyebrow_contour_points: [[Int]]
        let right_eyebrow_contour_points: [[Int]]
    }
    
    struct SkinToneDetectionResponse: Codable {
        let message: String
        let session_id: String
        let navigation_instruction: String
    }
    
    // Local instance constants.
    /*let TEST_USER_ID = "86d74345-b0f0-46ab-b8bd-b94c72362079"
    let HTTPS_PREFIX = "https://"
    let DOMAIN_PREFIX = "1365-73-202-97-212"
    let DOMAIN = ".ngrok.io"*/
    
    // AWS instance constants.
    let TEST_USER_ID = "9586a2ce-60d0-488f-817a-43260e40236a"
    let HTTPS_PREFIX = "http://"
    let DOMAIN_PREFIX = "facemagik-test.eba-24rwkh9x"
    let DOMAIN = ".us-west-2.elasticbeanstalk.com"
    
    let ENDPOINT = "/foundation/session/"
    let USER_QUERY_PARAM = "?user_id="
    
    
    // Header constants.
    let HTTP_GET_METHOD = "GET"
    let HTTP_POST_METHOD = "POST"
    let APPLICATION_JSON = "application/json"
    let CONTENT_TYPE = "Content-Type"
    
    var backendRequestStartTime: Date = Date()
    
    
    // Delegate object.
    var sessionResponseHandler: SessionResponseHandler?
    
    init(sessionResponseHandler: SessionResponseHandler?) {
        self.sessionResponseHandler = sessionResponseHandler
    }
    
    
    // Request to create a new skin tone session for given user.
    func createSkinToneSession() {
        let getURL = HTTPS_PREFIX + DOMAIN_PREFIX + DOMAIN + ENDPOINT + USER_QUERY_PARAM + TEST_USER_ID
        guard let url = URL(string: getURL) else {
            print ("Could not initialize URL string: \(getURL)")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = HTTP_GET_METHOD
        request.setValue(APPLICATION_JSON, forHTTPHeaderField: CONTENT_TYPE)
        
        
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            if let error = error {
                print("Error in sending GET request \(error)")
                return
            }
            
            if let response = response as? HTTPURLResponse {
                print("GET Response Status code: \(response.statusCode)")
            }
            
            
            guard let data = data else {
                print ("Error! No data in the response")
                return
            }
            
            
            var sessionCreationResponse: SessionCreationResponse?
            do {
                sessionCreationResponse = try JSONDecoder().decode(SessionCreationResponse.self, from: data)
            } catch let err {
                print ("Error in JSON deserialization: \(err.localizedDescription)")
                return
            }
            
            guard let sessionCreationResponse = sessionCreationResponse else {
                print ("New Session Created response is nil")
                return
            }
            
            
            // Call back delegate.
            self.sessionResponseHandler?.onSessionCreation(sessionId: sessionCreationResponse.session_id)
        }
        
        task.resume()
        
    }
    
    func detectskinTone(sessionId: String, uiImage: UIImage, contourPoints: ContourPoints) {
        let postURL = HTTPS_PREFIX + DOMAIN_PREFIX + DOMAIN + ENDPOINT
        guard let url = URL(string: postURL) else {
            print ("Could not initialize URL string: \(postURL)")
            return
        }
        
        // Resizing image further so server can process the image faster.
        let resizedWidth = CGFloat(400)
        let newuiImage = uiImage.resized(toWidth: resizedWidth)!
        
        var request = URLRequest(url: url)
        request.httpMethod = HTTP_POST_METHOD
        request.setValue(APPLICATION_JSON, forHTTPHeaderField: CONTENT_TYPE)
        
        let base64Image = Utils.tobase64String(uiImage: newuiImage)
        let skinToneDetectionRequest = SkinToneDetectionRequest(session_id: sessionId, image_name: "test_ios.png", image: base64Image, nose_middle_point: contourPoints.noseMiddePoint, face_till_nose_end_contour_points: contourPoints.faceTillNoseEndContourPoints, mouth_without_lips_contour_points: contourPoints.mouthWithoutLipsContourPoints, mouth_with_lips_contour_points:contourPoints.mouthWithLipsContourPoints, left_eye_contour_points: contourPoints.leftEyeContourPoints, right_eye_contour_points: contourPoints.rightEyeContourPoints, left_eyebrow_contour_points: contourPoints.leftEyebrowContourPoints, right_eyebrow_contour_points: contourPoints.rightEyebrowContourPoints)
        
        var jsonBody: Data
        do {
            jsonBody = try JSONEncoder().encode(skinToneDetectionRequest)
        } catch let err {
            print ("Error in JSON encoding: \(err.localizedDescription)")
            return
        }
        request.httpBody = jsonBody
        
        backendRequestStartTime = Date()
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            if let error = error {
                print("Error in sending POST request \(error)")
                return
            }
            
            if let response = response as? HTTPURLResponse {
                print("POST Response Status code: \(response.statusCode)")
            }
            
            
            guard let data = data else {
                print ("Error! No data in the response")
                return
            }
            
            
            var skinToneDetectionResponse: SkinToneDetectionResponse
            do {
                skinToneDetectionResponse = try JSONDecoder().decode(SkinToneDetectionResponse.self, from: data)
            } catch let err {
                print ("Error in JSON deserialization: \(err.localizedDescription)")
                return
            }
            
            print ("Skin tone backend request time: \(Date().timeIntervalSince(self.backendRequestStartTime))")
            
            // Call back delegate.
            self.sessionResponseHandler?.userNavigationInstruction(instruction: skinToneDetectionResponse.navigation_instruction)
            
        }
        
        task.resume()
    }
}
