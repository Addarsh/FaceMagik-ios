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
    }
    
    struct SkinToneDetectionResponse: Codable {
        let message: String
        let session_id: String
        let navigation_instruction: String
    }
    
    let TEST_USER_ID = "86d74345-b0f0-46ab-b8bd-b94c72362079"
    let HTTPS_PREFIX = "https://"
    let DOMAIN_PREFIX = "1365-73-202-97-212"
    let DOMAIN = ".ngrok.io"
    let ENDPOINT = "/foundation/session/"
    let USER_QUERY_PARAM = "?user_id="
    
    
    // Header constants.
    let HTTP_GET_METHOD = "GET"
    let HTTP_POST_METHOD = "POST"
    let APPLICATION_JSON = "application/json"
    let CONTENT_TYPE = "Content-Type"
    
    
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
    
    func detectskinTone(sessionId: String, ciImage: CIImage) {
        let postURL = HTTPS_PREFIX + DOMAIN_PREFIX + DOMAIN + ENDPOINT
        guard let url = URL(string: postURL) else {
            print ("Could not initialize URL string: \(postURL)")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = HTTP_POST_METHOD
        request.setValue(APPLICATION_JSON, forHTTPHeaderField: CONTENT_TYPE)
        
        guard let uiImage = UIImage(ciImage: ciImage, scale: 1.0, orientation: UIImage.Orientation.right).resized(toWidth: 720) else {
            print ("UIImage resize failed")
            return
        }
        let base64Image = Utils.tobase64String(uiImage: uiImage)
        let skinToneDetectionRequest = SkinToneDetectionRequest(session_id: sessionId, image_name: "test_ios.png", image: base64Image)
        
        var jsonBody: Data
        do {
            jsonBody = try JSONEncoder().encode(skinToneDetectionRequest)
        } catch let err {
            print ("Error in JSON encoding: \(err.localizedDescription)")
            return
        }
        request.httpBody = jsonBody
        
        print ("read to make request")
        
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
            
            // Call back delegate.
            self.sessionResponseHandler?.userNavigationInstruction(instruction: skinToneDetectionResponse.navigation_instruction)
            
        }
        
        task.resume()
    }
}
