//
//  Lbryio.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 10/11/2020.
//

import Foundation
 
final class Lbryio {
    static let methodGet = "GET"
    static let methodPost = "POST"
    
    static var generatingAuthToken: Bool = false
    static let connectionString = "https://api.lbry.com"
    static let wsConnectionBaseUrl = "wss://api.lbry.com/subscribe?auth_token="
    static let authTokenParam = "auth_token"
    static var authToken: String? = nil
    
    static let keyAuthToken = "AuthToken"
    
    static func call(resource: String, action: String, options: Dictionary<String, String>?, method: String, completion: @escaping (Any?, Error?) -> Void) throws {
        let url = String(format: "%@/%@/%@", connectionString, resource, action)
        if ((authToken ?? "").isBlank && !generatingAuthToken) {
            // generate the auth token before calling this resource
            try getAuthToken(completion: { token, error in
                if (!(token ?? "").isBlank) {
                    // auth token could not be generated, maybe try again
                    Lbryio.authToken = token
                    
                    // Persist the token
                    let defaults = UserDefaults.standard
                    defaults.set(token, forKey: keyAuthToken)
                }
                
                // send the call after the auth token has been retrieved
                do {
                    try call(resource: resource, action: action, options: options, method: method, completion: completion)
                } catch let error {
                    completion(nil, error)
                }
            })
            return
        }
        
        var requestUrl = URL(string: url)
        if (method.lowercased() == methodGet.lowercased()) {
            var queryItems: [URLQueryItem] = []
            if (!(authToken ?? "").isBlank) {
                queryItems.append(URLQueryItem(name: authTokenParam, value: authToken))
            }
            if (options != nil) {
                for (name, value) in options! {
                    queryItems.append(URLQueryItem(name: name, value: value))
                }
            }
            var urlComponents = URLComponents(string: url)
            urlComponents?.queryItems = queryItems
            requestUrl = urlComponents?.url!
        }

        let session = URLSession.shared
        var req = URLRequest(url: requestUrl!)
        req.httpMethod = method
        if (method.lowercased() == methodPost.lowercased()) {
            req.httpBody = buildQueryString(authToken: authToken, options: options).data(using: .utf8)
        }
        
        let task = session.dataTask(with: req, completionHandler: { data, response, error in
            guard let data = data, error == nil else {
                // handle error
                completion(nil, error)
                return
            }
            do {
                var respCode:Int = 0
                if let httpResponse = response as? HTTPURLResponse {
                    respCode = httpResponse.statusCode
                }
                let respData = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                
                /*print(respData)
                if let JSONString = String(data: data, encoding: String.Encoding.utf8) {
                   print(JSONString)
                }*/
                
                if (respCode >= 200 && respCode < 300) {
                    if (respData?["data"] == nil) {
                        completion(nil, nil)
                        return
                    }
                    completion(respData?["data"], nil)
                    return
                }
                
                if (respData?["error"] != nil) {
                    completion(nil, LbryioResponseError.runtimeError(respData?["error"] as! String, respCode))
                } else {
                    completion(nil, LbryioResponseError.runtimeError("Unknown api error signature", respCode))
                }
            } catch let error {
                completion(nil, error)
            }
        });
        task.resume();
    }
    
    static func buildQueryString(authToken: String?, options: Dictionary<String, String>?) -> String {
        var delim = ""
        var qs = ""
        if (!(authToken ?? "").isBlank) {
            qs.append(authTokenParam)
            qs.append("=")
            qs.append(authToken!.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!)
            delim = "&"
        }
        if (options != nil) {
            for (name, value) in options! {
                qs.append(delim)
                qs.append(name)
                qs.append("=")
                qs.append(value.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!)
                delim = "&"
            }
        }
        
        return qs
    }
    
    static func getAuthToken(completion: @escaping (String?, Error?) -> Void) throws {
        if ((Lbry.installationId ?? "").isBlank) {
            throw LbryioRequestError.runtimeError("The installation ID is not set")
        }
        
        generatingAuthToken = true
        var options: Dictionary<String, String> = Dictionary<String, String>()
        options[authTokenParam] = ""
        options["language"] = "en"
        options["app_id"] = Lbry.installationId!
        
        try call(resource: "user", action: "new", options: options, method: "post", completion: { data, error in
            generatingAuthToken = false
            if (data != nil) {
                let tokenData = data as! [String: Any]?
                let token: String? = tokenData?["auth_token"] as? String
                if ((token ?? "").isBlank) {
                    completion(nil, LbryioResponseError.runtimeError("auth_token was not set in the response", 0))
                    return
                }
                completion(token, nil)
            }
        })
    }
    
    static func fetchCurrentUser(completion: @escaping (User?, Error?) -> Void) throws {
        try call(resource: "user", action: "me", options: nil, method: methodGet, completion: { data, error in
            if (error != nil) {
                completion(nil, error)
                return
            }
            
            if (data != nil) {
                let jsonData = try! JSONSerialization.data(withJSONObject: data as Any, options: [.prettyPrinted, .sortedKeys])
                do {
                    let user: User? = try JSONDecoder().decode(User.self, from: jsonData)
                    if (user != nil) {
                        completion(user, nil)
                    }
                } catch let error {
                    completion(nil, error)
                }
            }
        })
    }
    
    static func newInstall(completion: @escaping (Error?) -> Void) throws {
        var options: Dictionary<String, String> = Dictionary<String, String>()
        options["app_version"] = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as! String)
        options["app_id"] = Lbry.installationId
        options["daemon_version"] = ""
        options["node_id"] = ""
        options["operating_system"] = "ios"
        options["platform"] = "darwin"
        options["domain"] = "odysee"
        try call(resource: "install", action: "new", options: options, method: methodPost, completion: { data, error in
            if (error != nil) {
                completion(error)
                return
            }
            // successful
            completion(nil)
        })
    }
}

enum LbryioRequestError: Error {
    case runtimeError(String)
}
enum LbryioResponseError: Error {
    case runtimeError(String, Int)
}
