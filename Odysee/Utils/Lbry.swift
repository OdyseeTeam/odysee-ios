//
//  Lbry.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 02/11/2020.
//

import Base58Swift
import CoreData
import CryptoKit
import os
import Foundation

final class Lbry {
    static let ttlCLaimSearchValue = 120000
    static let lbrytvURL = URL(string: "https://api.lbry.tv/api/v1/proxy")!
    static let lbrytvConnectionString = lbrytvURL.absoluteString
    static let keyShared = "shared"
    static let sharedPreferenceVersion = "0.1"
    
    static var walletSyncInProgress = false
    static var pushWalletSyncQueueCount = 0
    
    struct Page<Item: Decodable>: Decodable {
        var items: [Item]
        var page_size: Int
    }

    struct Method<ResultType: Decodable> {
        let name: String
    }

    struct Methods {
        static let resolve      = Method<[String: Claim]>(name: "resolve")
        static let claimSearch  = Method<Page<Claim>>(name: "claim_search")
    }

    static let methodClaimSearch = Methods.claimSearch.name
    static let methodResolve = Methods.resolve.name
    static let methodAddressUnused = "address_unused"
    static let methodChannelAbandon = "channel_abandon"
    static let methodChannelCreate = "channel_create"
    static let methodChannelUpdate = "channel_update"
    static let methodCommentCreate = "comment_create"
    static let methodStreamAbandon = "stream_abandon"
    static let methodStreamUpdate = "stream_update"
    static let methodChannelSign = "channel_sign"
    static let methodPublish = "publish"
    static let methodClaimList = "claim_list"
    static let methodCommentList = "comment_list"
    static let methodCommentReact = "comment_react"
    static let methodCommentReactList = "comment_react_list"
    static let methodPreferenceGet = "preference_get"
    static let methodPreferenceSet = "preference_set"
    static let methodSupportCreate = "support_create"
    static let methodSyncHash = "sync_hash"
    static let methodSyncApply = "sync_apply"
    static let methodTransactionList = "transaction_list"
    static let methodWalletBalance = "wallet_balance"
    static let methodWalletStatus = "wallet_status"
    static let methodWalletUnlock = "wallet_unlock"
    static let methodWalletSend = "wallet_send"
    
    static var installationId: String? = nil
    static let keyInstallationId = "AppInstallationId"
    
    static var remoteWalletHash: String? = nil
    static var localWalletHash: String? = nil
    static var walletBalance: WalletBalance? = nil
    
    static var claimCacheById: Dictionary<String, Claim> = Dictionary<String, Claim>()
    static var claimCacheByUrl: Dictionary<String, Claim> = Dictionary<String, Claim>()
    static var ownChannels: [Claim] = []
    static var ownUploads: [Claim] = []
    
    static private func apiRequest(method: String,
                                   params: [String: Any],
                                   url: URL,
                                   authToken: String?) -> URLRequest {
        let counter = Date().timeIntervalSince1970
        let body: Dictionary<String, Any> = [
            "jsonrpc": "2.0",
            "method": method,
            "params": params,
            "counter": counter
        ];
        
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.httpBody = try! JSONSerialization.data(withJSONObject: body, options: .prettyPrinted)
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.addValue("application/json", forHTTPHeaderField: "Accept")
        if let authToken = authToken, !authToken.isBlank {
            req.addValue(authToken, forHTTPHeaderField: "X-Lbry-Auth-Token")
        }
        return req
    }

    private struct APIError: Decodable {
        var code: Int
        var message: String
    }
    
    private struct APIResponse<Wrapped: Decodable>: Decodable {
        var jsonrpc: String
        var error: APIError?
        var result: Wrapped?
    }
    
    // `transform` is run off-main before completion to do things like sorting/filtering. Be cafeful!
    // Delivers the parsed Result on the main thread.
    static func apiCall<Value: Decodable>(method: Method<Value>,
                                          params: [String: Any],
                                          url: URL,
                                          authToken: String? = nil,
                                          transform: ((inout Value) throws -> ())? = nil,
                                          completion: @escaping (Result<Value, Error>) -> Void) {
        let req = apiRequest(method: method.name, params: params, url: url, authToken: authToken)
        let task = URLSession.shared.dataTask(with: req) { taskResult in
            // Do the parse, compute the result here on network thread.
            let result: Result<Value, Error> = taskResult.flatMap { rawResponse in
                Result {
                    os_log(.debug, log: Log.verboseJSON,
                           "Response to `\(method.name)`: \(String(data: rawResponse.data, encoding: .utf8)!)")

                    let response = try JSONDecoder().decode(APIResponse<Value>.self, from: rawResponse.data)
                    assert(response.jsonrpc == "2.0")

                    // no result inside response
                    guard var result = response.result else {
                        throw LbryApiResponseError(response.error?.message ?? "unknown api error")
                    }
                    try transform?(&result)
                    return result
                }
            }

            if case let .failure(e as DecodingError) = result {
                assertionFailure("Decode error \(e)")
            }

            // Then deliver it to main.
            DispatchQueue.main.async {
                completion(result)
            }
        }
        task.resume()
    }
    
    // Delivers the result on a background thread as a [String: Any].
    // New code should migrate to the version above that delivers on main.
    static func apiCall(method: String, params: Dictionary<String, Any>, connectionString: String, authToken: String? = nil, completion: @escaping ([String: Any]?, Error?) -> Void) {
        let req = apiRequest(method: method, params: params, url: URL(string: connectionString)!, authToken: authToken)
        let task = URLSession.shared.dataTask(with: req, completionHandler: { data, response, error in
            guard let data = data, error == nil else {
                // handle error
                completion(nil, error)
                return
            }
            do {
                os_log(.debug, log: Log.verboseJSON, "Response to `\(method)`: \(String(data: data, encoding: .utf8)!)")
                
                let response = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                if (response?["result"] != nil) {
                    completion(response, nil)
                } else {
                    if response?["error"] == nil && response?["result"] == nil {
                        completion(nil, nil)
                    } else if (response?["error"] as? String != nil) {
                        completion(nil, LbryApiResponseError(response?["error"] as! String))
                    } else if let errorJson = response?["error"] as? [String: Any] {
                        completion(nil, LbryApiResponseError(errorJson["message"] as! String))
                    } else {
                        completion(nil, LbryApiResponseError("unknown api error"))
                    }
                }
            } catch let error {
                completion(nil, error)
            }
        });
        task.resume();
    }
    
    static func addClaimToCache(claim: Claim?) {
        if (claim != nil) {
            Lbry.claimCacheById[(claim?.claimId!)!] = claim
            let claimUrl: LbryUri? = LbryUri.tryParse(url: (claim?.permanentUrl!)!, requireProto: false)
            if (claimUrl != nil) {
                Lbry.claimCacheByUrl[claimUrl!.description] = claim
            }
            if !(claim?.shortUrl ?? "").isBlank {
                Lbry.claimCacheByUrl[claim!.shortUrl!] = claim
            }
            if !(claim?.canonicalUrl ?? "").isBlank {
                Lbry.claimCacheByUrl[claim!.canonicalUrl!] = claim
            }
        }
    }
    
    static func buildClaimSearchOptions(
        claimType: [String]?,
        anyTags: [String]?,
        notTags: [String]?,
        channelIds: [String]?,
        notChannelIds: [String]?,
        claimIds: [String]?,
        orderBy: [String]?,
        releaseTime: String?,
        maxDuration: Int64?,
        limitClaimsPerChannel: Int,
        hasNoSource: Bool? = false,
        page: Int,
        pageSize: Int) -> Dictionary<String, Any> {
        var options: Dictionary<String, Any> = [String: Any]()
        
        if (claimType != nil) {
            options["claim_type"] = claimType
        }
        options["no_totals"] = true
        options["page"] = page
        options["page_size"] = pageSize
        if (!(releaseTime ?? "").isBlank) {
            options["release_time"] = releaseTime
        }
        if ((maxDuration ?? 0) > 0) {
            options["duration"] = String(format: "<%d", maxDuration!)
        }
        if (limitClaimsPerChannel > 0) {
            options["limit_claims_per_channel"] = limitClaimsPerChannel
        }
        
        options["has_no_source"] = hasNoSource
        
        addClaimSearchListOption(key: "any_tags", list: anyTags, options: &options)
        addClaimSearchListOption(key: "not_tags", list: notTags, options: &options)
        addClaimSearchListOption(key: "channel_ids", list: channelIds, options: &options)
        addClaimSearchListOption(key: "not_channel_ids", list: notChannelIds, options: &options)
        addClaimSearchListOption(key: "claim_ids", list: claimIds, options: &options)
        addClaimSearchListOption(key: "order_by", list: orderBy, options: &options)
        
        return options
    }
    
    static func addClaimSearchListOption(key: String, list: [String]?, options: inout Dictionary<String, Any>) {
        if ((list ?? []).count > 0) {
            options[key] = list
        }
    }
    
    static func generateId() -> String? {
        return generateId(numBytes: 64)
    }
    static func generateId(numBytes: Int) -> String? {
        var data = Data(count: numBytes)
        let result = data.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, numBytes, $0.baseAddress!)
        }
        if (result == errSecSuccess) {
            let hash = SHA384.hash(data: data)
            return Base58.base58Encode(Array(hash.makeIterator()))
        }
        return nil
    }
    
    static func loadSharedUserState(completion: @escaping (Bool, Error?) -> Void) {
        getSharedPreference(completion: { data, newState, error in
            guard let data = data, error == nil else {
                completion(false, error)
                return
            }
            
            let shared = data["shared"] as? [String: Any]
            if shared != nil && shared!["type"] as? String == "object" && shared!["value"] as? [String: Any] != nil {
                // load subscriptions only
                let value = shared!["value"] as! [String: Any]
                let subscriptionUrls = value["subscriptions"] as? [String]
                let following = value["following"] as? [[String: Any]]
                
                var sharedPrefSubs: [LbrySubscription] = []
                for urlString in subscriptionUrls! {
                    let url: LbryUri? = LbryUri.tryParse(url: urlString, requireProto: false)
                    if url != nil {
                        sharedPrefSubs.append(buildSharedPreferenceSubscription(url!, following: following ?? []))
                    }
                }
                
                processSharedPreferenceSubs(sharedPrefSubs)
            }
            
            completion(true, nil)
        })
    }
    
    static func processSharedPreferenceSubs(_ subs: [LbrySubscription]) {
        if subs.count > 0 {
            // clear all subscriptions in local state
            Lbryio.cachedSubscriptions.removeAll()
            for sub in subs {
                let lbryUrl = LbryUri.tryParse(url: String(format: "%@#%@", normalizeChannelName(sub.channelName!), sub.claimId!), requireProto: false)
                if lbryUrl != nil {
                    Lbryio.addSubscription(sub: sub, url: lbryUrl!.description)
                }
            }
        }
    }
    
    static func buildSharedPreferenceSubscription(_ url: LbryUri, following: [[String: Any]]?) -> LbrySubscription {
        var sub = LbrySubscription()
        sub.channelName = normalizeChannelName(url.channelName!)
        sub.claimId = url.claimId
        sub.notificationsDisabled = isNotificationsDisabledForSubUrl(url.description, following: following)
        return sub
    }
    
    static func normalizeChannelName(_ channelName: String) -> String {
        var name = channelName
        if (!name.starts(with: "@")) {
            name = String(format: "@%@", name)
        }
        return name
    }
    
    static func isNotificationsDisabledForSubUrl(_ url: String, following: [[String: Any]]?) -> Bool {
        if following != nil {
            for item in following! {
                if item["uri"] as? String == url {
                    return (item["notificationsDisabled"] as? Bool) ?? true
                }
            }
        }
        return true
    }
    
    static func saveSharedUserState(completion: @escaping (Bool, Error?) -> Void) {
        getSharedPreference(completion: { data, newState, error in
            if error != nil {
                print(error!.localizedDescription)
                return
            }
            
            var shared: [String: Any]? = nil
            var existingDataValid = false
            if data != nil {
                shared = data!["shared"] as? [String: Any]
                if shared != nil && shared!["type"] as? String == "object" && shared!["value"] as? [String: Any] != nil {
                    existingDataValid = true
                    let (subscriptionUrls, following) = buildSubscriptionUrlsAndFollowingPreferences()
                    var newValue = shared!["value"] as! [String: Any]
                    newValue["subscriptions"] = subscriptionUrls
                    newValue["following"] = following
                    shared!["value"] = newValue
                }
            }
            
            if newState || !existingDataValid {
                shared = [
                    "version": sharedPreferenceVersion,
                    "type": "object",
                    "value": buildNewSharedPreference()
                ]
            }
            
            let dataToSave = try! JSONSerialization.data(withJSONObject: shared as Any, options: [.prettyPrinted, .sortedKeys])
            var params = Dictionary<String, Any>()
            params["key"] = keyShared
            params["value"] = String(data: dataToSave, encoding: String.Encoding.utf8)!
            apiCall(method: methodPreferenceSet, params: params, connectionString: lbrytvConnectionString, authToken: Lbryio.authToken, completion: { data, error in
                guard let _ = data, error == nil else {
                    completion(false, error)
                    return
                }
            
                completion(true, nil)
            })
        })
    }
    
    static func buildNewSharedPreference() -> Dictionary<String, Any> {
        let (subscriptionUrls, following) = buildSubscriptionUrlsAndFollowingPreferences()
        var preference = Dictionary<String, Any>()
        preference["tags"] = [] // tags not supported right now, so just make it an empty list
        preference["subscriptions"] = subscriptionUrls
        preference["following"] = following
        
        return preference
    }
    
    static func buildSubscriptionUrlsAndFollowingPreferences() -> ([String], [[String: Any]]) {
        var subscriptionUrls: [String] = []
        var following: [[String: Any]] = []
        for (_, value) in Lbryio.cachedSubscriptions {
            let url: LbryUri? = LbryUri.tryParse(url: String(format:"%@#%@", normalizeChannelName(value.channelName!), value.claimId!), requireProto: false)
            if url != nil {
                subscriptionUrls.append(url!.description)
                following.append(["uri": url!.description, "notificationsDisabled": value.notificationsDisabled ?? true])
            }
        }
        
        return (subscriptionUrls, following)
    }
    
    static func getSharedPreference(completion: @escaping ([String: Any]?, Bool, Error?) -> Void) {
        var params = Dictionary<String, Any>()
        params["key"] = keyShared
        apiCall(method: methodPreferenceGet, params: params, connectionString: lbrytvConnectionString, authToken: Lbryio.authToken, completion: { data, error in
            guard error == nil else {
                completion(nil, false, error)
                return
            }
            
            if data == nil {
                completion(nil, true, nil)
                return
            }
            
            completion(data!["result"] as? [String: Any], false, nil)
        })
    }
    
    static func pullSyncWallet(completion: ((Bool) -> ())?) {
        if walletSyncInProgress {
            return
        }
        
        walletSyncInProgress = true
        apiCall(method: Lbry.methodSyncHash, params: Dictionary<String, Any>(), connectionString: Lbry.lbrytvConnectionString, authToken: Lbryio.authToken, completion: { data, error in
            guard let data = data, error == nil else {
                print(error!)
                self.walletSyncInProgress = false
                return
            }
            
            if let hash = data["result"] as? String {
                localWalletHash = hash
                Lbryio.syncGet(hash: hash, completion: { walletSync, needsNewWallet, wsError in
                    guard let walletSync = walletSync, wsError == nil else {
                        print(wsError)
                        self.walletSyncInProgress = false
                        return
                    }
                    
                    remoteWalletHash = walletSync.hash
                    if walletSync.changed! || localWalletHash != remoteWalletHash {
                        // sync apply changes
                        var params = Dictionary<String, Any>()
                        params["password"] = ""
                        params["data"] = walletSync.data
                        params["blocking"] = true
                        apiCall(method: methodSyncApply, params: params, connectionString: Lbry.lbrytvConnectionString, authToken: Lbryio.authToken, completion: { saData, saError in
                            guard let saData = saData, saError == nil else {
                                print(saError!)
                                if completion != nil {
                                    completion!(false)
                                }
                                self.walletSyncInProgress = false
                                return
                            }
                            
                            let result = saData["result"] as! [String: Any]
                            let saHash = result["hash"] as! String
                            localWalletHash = saHash
                        
                            self.walletSyncInProgress = false
                            self.loadSharedUserState(completion: { success, error in
                                if completion != nil {
                                    completion!(true)
                                }
                            })
                            
                            self.checkPushSyncQueue()
                        })
                    } else {
                        // no changes applied
                        self.walletSyncInProgress = false
                        self.loadSharedUserState(completion: { success, error in
                            // reload all the same
                            if completion != nil {
                                completion!(true)
                            }
                        })
                    }
                })
                
                return
            }
            
            self.walletSyncInProgress = false
        })
    }
    
    static func checkPushSyncQueue() {
        if pushWalletSyncQueueCount > 0 {
            self.pushWalletSyncQueueCount -= 1
            self.pushSyncWallet()
        }
    }
    
    static func pushSyncWallet() {
        if walletSyncInProgress {
            pushWalletSyncQueueCount = pushWalletSyncQueueCount + 1
            return
        }
        
        walletSyncInProgress = true
        var params = Dictionary<String, Any>()
        params["password"] = ""
        
        Lbry.apiCall(method: Lbry.methodSyncApply, params:params, connectionString: Lbry.lbrytvConnectionString, authToken: Lbryio.authToken, completion: { data, error in
            guard let data = data, error == nil else {
                self.walletSyncInProgress = false
                self.checkPushSyncQueue()
                return
            }
            
            if let result = data["result"] as? [String: Any] {
                let hash = result["hash"] as! String
                let walletData = result["data"] as! String
                
                Lbry.localWalletHash = hash
                Lbryio.syncSet(oldHash: remoteWalletHash!, newHash: hash, data: walletData, completion: { remoteHash, error in
                    guard let remoteHash = remoteHash, error == nil else {
                        self.walletSyncInProgress = false
                        self.checkPushSyncQueue()
                        print(error!)
                        return
                    }
                    
                    Lbry.remoteWalletHash = remoteHash
                    if Lbry.remoteWalletHash != Lbry.localWalletHash {
                        self.pullSyncWallet(completion: nil)
                    } else {
                        self.walletSyncInProgress = false
                        self.checkPushSyncQueue()
                    }
                })
                
                return
            }
            
            self.walletSyncInProgress = false
            self.checkPushSyncQueue()
        })
    }
}

struct LbryApiResponseError: Error {
    let message: String
    init (_ message: String) {
        self.message = message
    }
    public var localizedDescription: String {
        return message
    }
}
