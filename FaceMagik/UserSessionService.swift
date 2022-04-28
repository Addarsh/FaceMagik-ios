//
//  UserSessionService.swift
//  FaceMagik
//
//  Created by Addarsh Chandrasekar on 4/28/22.
//

import Foundation


class UserSessionService {
    
    struct UserSessionCreationRequest: Codable {
        let user_id: String
    }
    struct UserSessionCreationResponse: Codable {
        let user_id: String
        let user_session_id: String
    }
    
    private let remoteEndPoint = "http://facemagik-test.eba-24rwkh9x.us-west-2.elasticbeanstalk.com"
    private let localEndpoint = "https://334c-71-202-19-95.ngrok.io"
    
    private let localTestUserId = "86d74345-b0f0-46ab-b8bd-b94c72362079"
    private let remoteTestUserId = "9586a2ce-60d0-488f-817a-43260e40236a"
    
    private var is_remote_endpoint: Bool
    
    // Header constants.
    let HTTP_GETD = "GET"
    let HTTP_POST = "POST"
    let APPLICATION_JSON = "application/json"
    let CONTENT_TYPE = "Content-Type"
    
    // Delegate object.
    var userSessionServiceDelegate: UserSessionServiceDelegate?
    
    
    init(userSessionServiceDelegate: UserSessionServiceDelegate?, is_remote_endpoint: Bool) {
        self.userSessionServiceDelegate = userSessionServiceDelegate
        self.is_remote_endpoint = is_remote_endpoint
    }
    
    func createUserSession() {
        let endpoint = is_remote_endpoint ? remoteEndPoint : localEndpoint
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
            jsonBody = try JSONEncoder().encode(UserSessionCreationRequest(user_id: is_remote_endpoint ? remoteTestUserId : localTestUserId))
        } catch let err {
            print ("Error in JSON encoding: \(err.localizedDescription)")
            return
        }
        request.httpBody = jsonBody
        
        
        makeRequest(request: request, onSuccess: onUserSessionCreation)
    }
    
    // Handle successful user session creation.
    func onUserSessionCreation(_ data: Data) {
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
    
    
    // Shared method to make given request call to the backend. A successful response is handled by the onSuccess callback provided.
    private func makeRequest(request: URLRequest, onSuccess: @escaping (Data) -> Void) {
        let requestStartTime = Date()
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            print ("Backend Request took : \(Date().timeIntervalSince(requestStartTime)) seconds to complete")
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
