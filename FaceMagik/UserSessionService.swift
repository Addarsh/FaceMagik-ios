//
//  UserSessionService.swift
//  FaceMagik
//
//  Created by Addarsh Chandrasekar on 4/28/22.
//

import Foundation
import UIKit


class UserSessionService {
    
    struct UserSessionCreationRequest: Codable {
        let user_id: String
    }
    struct UserSessionCreationResponse: Codable {
        let user_id: String
        let user_session_id: String
    }
    
    struct UploadRotationImageRequest: Codable {
        let user_session_id: String
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
        let heading: Int
    }
    
    struct GetRotationResultResponse: Codable {
        let user_session_id: String
        let primary_light_heading: Int
    }
    
    private let remoteEndPoint = "http://facemagik-test.eba-24rwkh9x.us-west-2.elasticbeanstalk.com"
    private let localEndpoint = "https://3dc5-71-202-19-95.ngrok.io"
    
    private let localTestUserId = "86d74345-b0f0-46ab-b8bd-b94c72362079"
    private let remoteTestUserId = "9586a2ce-60d0-488f-817a-43260e40236a"
    
    private var endpoint: String
    private var testUserId: String
    
    // Header constants.
    let HTTP_GET = "GET"
    let HTTP_POST = "POST"
    let APPLICATION_JSON = "application/json"
    let CONTENT_TYPE = "Content-Type"
    
    // Delegate object.
    var userSessionServiceDelegate: UserSessionServiceDelegate?
    
    
    init(userSessionServiceDelegate: UserSessionServiceDelegate?, is_remote_endpoint: Bool) {
        self.userSessionServiceDelegate = userSessionServiceDelegate
        self.endpoint = is_remote_endpoint ? remoteEndPoint: localEndpoint
        self.testUserId = is_remote_endpoint ? remoteTestUserId : localTestUserId
    }
    
    // Create new user session for given test user.
    func createUserSession() {
        let urlStr = endpoint + "/foundation/user_session/"
        guard let url = URL(string: urlStr) else {
            print ("Could not initialize URL string: \(urlStr)")
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = HTTP_POST
        request.setValue(APPLICATION_JSON, forHTTPHeaderField: CONTENT_TYPE)
        
        // Attach POST body.
        var jsonBody: Data
        do {
            jsonBody = try JSONEncoder().encode(UserSessionCreationRequest(user_id: testUserId))
        } catch let err {
            print ("Error in JSON encoding: \(err.localizedDescription)")
            return
        }
        request.httpBody = jsonBody
        
        
        makeRequest(request: request, onSuccess: onUserSessionCreation, onReturn: {})
    }
    
    // Handle successful user session creation.
    private func onUserSessionCreation(_ data: Data) {
        var userSessioCreationResponse: UserSessionCreationResponse
        do {
            userSessioCreationResponse = try JSONDecoder().decode(UserSessionCreationResponse.self, from: data)
        } catch let err {
            print ("Error in JSON deserialization of session creation response: \(err.localizedDescription)")
            return
        }
        
        // Call back delegate.
        userSessionServiceDelegate?.onSessionCreation(userSessionId: userSessioCreationResponse.user_session_id)
    }
    
    // Upload rotation image to the server.
    func uploadRotationImage(userSessionId: String, uiImage: UIImage, contourPoints: ContourPoints, heading: Int) -> Bool {
        let urlStr = endpoint + "/foundation/user_session/rotation_image/"
        guard let url = URL(string: urlStr) else {
            print ("Could not initialize URL string: \(urlStr)")
            return false
        }
        var request = URLRequest(url: url)
        request.httpMethod = HTTP_POST
        request.setValue(APPLICATION_JSON, forHTTPHeaderField: CONTENT_TYPE)
        
        // Attach POST body.
        var jsonBody: Data
        let base64Image = Utils.tobase64String(uiImage: uiImage)
        let uploadRotationImageRequest = UploadRotationImageRequest(user_session_id: userSessionId, image: base64Image, nose_middle_point: contourPoints.noseMiddePoint, face_till_nose_end_contour_points: contourPoints.faceTillNoseEndContourPoints, mouth_without_lips_contour_points: contourPoints.mouthWithoutLipsContourPoints, mouth_with_lips_contour_points: contourPoints.mouthWithLipsContourPoints, left_eye_contour_points: contourPoints.leftEyeContourPoints, right_eye_contour_points: contourPoints.rightEyeContourPoints, left_eyebrow_contour_points: contourPoints.leftEyebrowContourPoints, right_eyebrow_contour_points: contourPoints.rightEyebrowContourPoints, heading: heading)
        do {
            jsonBody = try JSONEncoder().encode(uploadRotationImageRequest)
        } catch let err {
            print ("Error in JSON encoding: \(err.localizedDescription)")
            return false
        }
        request.httpBody = jsonBody
        
        makeRequest(request: request, onSuccess: {_ in}, onReturn: {self.userSessionServiceDelegate?.uploadRotationImageResponseReceived()})
        return true
    }
    
    // Fetch rotation result from server.
    func getRotationResult(userSessionId: String) {
        let urlStr = endpoint + "/foundation/user_session/rotation_result/?user_session_id=" + userSessionId
        guard let url = URL(string: urlStr) else {
            print ("Could not initialize URL string: \(urlStr)")
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = HTTP_GET
        request.setValue(APPLICATION_JSON, forHTTPHeaderField: CONTENT_TYPE)
        
        makeRequest(request: request, onSuccess: onRotationResult, onReturn: {})
    }
    
    private func onRotationResult(_ data: Data) {
        var getRotationResultResponse: GetRotationResultResponse
        do {
            getRotationResultResponse = try JSONDecoder().decode(GetRotationResultResponse.self, from: data)
        } catch let err {
            print ("Error in JSON deserialization of session creation response: \(err.localizedDescription)")
            return
        }
        userSessionServiceDelegate?.primaryHeadingDirection(heading: getRotationResultResponse.primary_light_heading)
    }
    
    
    // Shared method to make given request call to the backend. A successful response is handled by the onSuccess callback provided.
    private func makeRequest(request: URLRequest, onSuccess: @escaping (Data) -> Void, onReturn: @escaping () -> Void) {
        let requestStartTime = Date()
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            print ("Backend Request took : \(Date().timeIntervalSince(requestStartTime)) seconds to complete")
            onReturn()
            
            if let error = error {
                print("Error in sending POST request \(error)")
                return
            }
            
            if let response = response as? HTTPURLResponse {
                print("Response Status code: \(response.statusCode)")
            }
            
            
            guard let data = data else {
                print ("Error! No data in the response")
                return
            }
            
            onSuccess(data)
        }
        
        task.resume()
    }
    
}
