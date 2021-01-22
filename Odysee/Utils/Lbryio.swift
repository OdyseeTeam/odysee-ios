//
//  Lbryio.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 10/11/2020.
//

import Foundation
import Firebase
 
final class Lbryio {
    static let methodGet = "GET"
    static let methodPost = "POST"
    
    static var generatingAuthToken: Bool = false
    static let connectionString = "https://api.lbry.com"
    static let wsConnectionBaseUrl = "wss://api.lbry.com/subscribe?auth_token="
    static let authTokenParam = "auth_token"
    static var authToken: String? = nil
    
    static let keyAuthToken = "AuthToken"
    static var currentUser: User? = nil
    
    static var currentLbcUsdRate: Decimal? = 0
    static var followedUrls: [String] = [] // simple cache of followed urls
    static var cachedSubscriptions: Dictionary<String, LbrySubscription> = Dictionary<String, LbrySubscription>()
    static var cachedNotifications: [LbryNotification] = []
    static var latestNotificationId: Int64 = 0
    static var subscriptionsDirty = false
    
    static var filteredOutpoints: [String] = []
    static var blockedOutpoints: [String] = []
    
    static var cachedTwitterOauthToken: String? = nil
    static var cachedTwitterOauthTokenSecret: String? = nil
    
    static func call(resource: String, action: String, options: Dictionary<String, String>?, method: String, authTokenOverride: String? = nil, completion: @escaping (Any?, Error?) -> Void) throws {
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
        var queryItems: [URLQueryItem] = []
        if (!(authToken ?? "").isBlank) {
            queryItems.append(URLQueryItem(name: authTokenParam, value: authTokenOverride ?? authToken))
        }
        if (options != nil) {
            for (name, value) in options! {
                queryItems.append(URLQueryItem(name: name, value: value))
            }
        }
        var urlComponents = URLComponents(string: url)
        urlComponents?.queryItems = queryItems
        
        if (method.lowercased() == methodGet.lowercased()) {
            requestUrl = urlComponents?.url!
        }

        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        
        let session = URLSession(configuration: config)
        var req = URLRequest(url: requestUrl!)
        req.httpMethod = method
        if (method.lowercased() == methodPost.lowercased()) {
            req.httpBody = buildQueryString(authToken: authTokenOverride ?? authToken, options: options).data(using: .utf8)
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
                
                // TODO: remove
                if let JSONString = String(data: data, encoding: String.Encoding.utf8) {
                   //print(JSONString)
                }
                
                if (respCode >= 200 && respCode < 300) {
                    if (respData?["data"] == nil) {
                        completion(nil, nil)
                        return
                    }
                    completion(respData?["data"], nil)
                    return
                }
                
                if (respData?["error"] as? NSNull != nil) {
                    completion(nil, LbryioResponseError("no error message", respCode))
                } else if (respData?["error"] as? String != nil) {
                    completion(nil, LbryioResponseError(respData?["error"] as! String, respCode))
                } else {
                    completion(nil, LbryioResponseError("Unknown api error signature", respCode))
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
                qs.append(value.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!.replacingOccurrences(of: "+", with: "%2B"))
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
                    completion(nil, LbryioResponseError("auth_token was not set in the response", 0))
                    return
                }
                completion(token, nil)
            }
        })
    }
    
    static func isSignedIn() -> Bool {
        return currentUser != nil && !(currentUser?.primaryEmail ?? "").isEmpty
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
                        currentUser = user
                        Analytics.setDefaultEventParameters([
                            "user_id": currentUser!.id!,
                            "user_email": currentUser!.primaryEmail ?? ""
                        ])
                        
                        completion(user, nil)
                    }
                } catch let error {
                    completion(nil, error)
                }
            }
        })
    }
    
    static func newInstall(completion: @escaping (Error?) -> Void) {
        Messaging.messaging().token(completion: { token, error in
            if (error != nil) {
                // no need to fail on error here
                print(error!)
            }
            
            var options: Dictionary<String, String> = Dictionary<String, String>()
            options["app_version"] = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as! String)
            options["app_id"] = Lbry.installationId
            options["daemon_version"] = ""
            options["node_id"] = ""
            options["operating_system"] = "ios"
            options["platform"] = "darwin"
            options["domain"] = "odysee.com"
            if !(token ?? "").isBlank {
                options["firebase_token"] = token!
            }
            do {
                try call(resource: "install", action: "new", options: options, method: methodPost, completion: { data, error in
                    if (error != nil) {
                        completion(error)
                        return
                    }
                    // successful
                    completion(nil)
                })
            } catch let error {
                completion(error)
            }
        })
    }
    
    static func loadExchangeRate(completion: @escaping(Decimal?, Error?) -> Void) {
        do {
            try call(resource: "lbc", action: "exchange_rate", options: nil, method: methodGet, completion: { data, error in
                guard let data = data, error == nil else {
                    completion(nil, error)
                    return
                }
                
                let response = data as! [String: Any]
                let lbcUsdRate = response["lbc_usd"] as? Double
                if (lbcUsdRate != nil) {
                    currentLbcUsdRate = Decimal(lbcUsdRate!)
                    completion(currentLbcUsdRate, nil)
                    return
                }
                
                completion(nil, LbryioResponseError("exchange rate retrieval failed", 0))
            })
        } catch let error {
            completion(nil, error)
        }
    }
    
    static func syncSet(oldHash: String, newHash: String, data: String, completion: @escaping (String?, Error?) -> Void) {
        var options = Dictionary<String, String>()
        options["old_hash"] = oldHash
        options["new_hash"] = newHash
        options["data"] = data
        do {
            try Lbryio.call(resource: "sync", action: "set", options: options, method: Lbryio.methodPost, completion: { data, error in
                guard let data = data, error == nil else {
                    completion(nil, error)
                    return
                }
                
                let response = data as! [String: Any]
                let remoteHash = response["hash"] as! String
                completion(remoteHash, nil)
            })
        } catch let error {
            completion(nil, error)
        }
    }
    
    static func syncGet(hash: String, applySyncChanges: Bool = false, completion: @escaping (WalletSync?, Bool?, Error?) -> Void) {
        var options = Dictionary<String, String>()
        options["hash"] = hash
        do {
            try Lbryio.call(resource: "sync", action: "get", options: options, method: Lbryio.methodPost, completion: { data, error in
                guard let data = data, error == nil else {
                    if let responseError = error as? LbryioResponseError {
                        if (responseError.code == 404) {
                            // no wallet found for the user, so it's a new sync
                            completion(nil, true, nil)
                            return
                        }
                    }
                    completion(nil, nil, error)
                    return
                }
                
                let response = data as! [String: Any]
                var walletSync = WalletSync()
                walletSync.hash = response["hash"] as? String
                walletSync.data = response["data"] as? String
                walletSync.changed = response["changed"] as? Bool
                completion(walletSync, false, nil)
            })
        } catch let error {
            completion(nil, nil, error)
        }
    }
    
    static func addSubscription(sub: LbrySubscription, url: String?) {
        let url = LbryUri.tryParse(url: url!, requireProto: false)
        if (url != nil) {
            cachedSubscriptions[url!.description] = sub
        }
    }
    static func removeSubscription(subUrl: String?) {
        let url = LbryUri.tryParse(url: subUrl!, requireProto: false)
        if (url != nil) {
            cachedSubscriptions.removeValue(forKey: url!.description)
        }
    }
    
    static func isFollowing(claim: Claim) -> Bool {
        let url = LbryUri.tryParse(url: claim.permanentUrl!, requireProto: false)
        return url != nil && cachedSubscriptions[url!.description] != nil
    }
    static func isFollowing(subscription: Subscription) -> Bool {
        let url = LbryUri.tryParse(url: subscription.url!, requireProto: false)
        return url != nil && cachedSubscriptions[url!.description] != nil
    }
    static func isNotificationsDisabledForSub(claim: Claim) -> Bool {
        let url = LbryUri.tryParse(url: claim.permanentUrl!, requireProto: false)
        if url != nil && cachedSubscriptions[url!.description] != nil {
            return cachedSubscriptions[url!.description]!.notificationsDisabled ?? true
        }
        
        return true
    }
    
    static func isClaimFiltered(_ claim: Claim) -> Bool {
        return filteredOutpoints.contains(String(format: "%@:%d", claim.txid!, claim.nout!))
    }
    static func isClaimBlocked(_ claim: Claim) -> Bool {
        return blockedOutpoints.contains(String(format: "%@:%d", claim.txid!, claim.nout!))
    }
}

enum LbryioRequestError: Error {
    case runtimeError(String)
}
struct LbryioResponseError: Error {
    let message: String
    let code: Int
    init (_ message: String, _ code: Int) {
        self.message = message
        self.code = code
    }
    public var localizedDescription: String {
        return message
    }
}
