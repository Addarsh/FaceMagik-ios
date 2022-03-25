//
//  BackendService.swift
//  FaceMagik
//
//  Created by Addarsh Chandrasekar on 3/24/22.
//
import Foundation

class BackendService {
    struct SessionCreationResponse: Codable {
        let message: String
        let session_id: String
    }
    
    let TEST_USER_ID = "86d74345-b0f0-46ab-b8bd-b94c72362079"
    let HTTPS_PREFIX = "https://"
    let DOMAIN_PREFIX = "1365-73-202-97-212"
    let DOMAIN = ".ngrok.io"
    let ENDPOINT = "/foundation/session/"
    let USER_QUERY_PARAM = "?user_id="
    
    // Delegate object.
    var sessionResponseHandler: SessionResponseHandler?
    
    init(sessionResponseHandler: SessionResponseHandler?) {
        self.sessionResponseHandler = sessionResponseHandler
    }
    
    
    // Request to create a new skin tone session for given user.
    func createSkinToneSession() {
        let getURL = HTTPS_PREFIX + DOMAIN_PREFIX + DOMAIN + ENDPOINT + USER_QUERY_PARAM + TEST_USER_ID
        guard let url = URL(string: getURL) else {
            print ("Could not initialize URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            if let error = error {
                print("Error in sending GET request \(error)")
                return
            }
            
            if let response = response as? HTTPURLResponse {
                print("Response Status code: \(response.statusCode)")
            }
            
            
            guard let data = data else {
                print ("Error! No data in the response")
                return
            }
            
            
            var sessionCreationResponse: SessionCreationResponse?
            do {
                sessionCreationResponse = try JSONDecoder().decode(SessionCreationResponse.self, from: data)
            } catch {
                print ("Error in JSON deserialization")
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
}
