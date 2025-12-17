//
//  Lbryio.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 10/11/2020.
//

import FirebaseAnalytics
import FirebaseCrashlytics
import FirebaseMessaging
import Foundation
import os

enum Lbryio {
    enum Method: String {
        case GET
        case POST
        func isEqual(toString str: String) -> Bool {
            return str.uppercased() == rawValue.uppercased()
        }
    }

    enum Defaults {
        private enum Key: String {
            case ChannelsAssociated
            case EmailRewardClaimed
            case YouTubeSyncConnected
            case YouTubeSyncDone
        }

        private static func get(string: Key) -> String? {
            return UserDefaults.standard.string(forKey: string.rawValue)
        }

        private static func set(string: Key, value: String?) {
            UserDefaults.standard.set(value, forKey: string.rawValue)
        }

        private static func get(bool: Key) -> Bool {
            return UserDefaults.standard.bool(forKey: bool.rawValue)
        }

        private static func set(bool: Key, value: Bool) {
            UserDefaults.standard.set(value, forKey: bool.rawValue)
        }

        static var isEmailRewardClaimed: Bool {
            get {
                return get(bool: .EmailRewardClaimed)
            }
            set {
                set(bool: .EmailRewardClaimed, value: newValue)
            }
        }

        static var isChannelsAssociated: Bool {
            get {
                return get(bool: .ChannelsAssociated)
            }
            set {
                set(bool: .ChannelsAssociated, value: newValue)
            }
        }

        static var isYouTubeSyncConnected: Bool {
            get {
                return get(bool: .YouTubeSyncConnected)
            }
            set {
                set(bool: .YouTubeSyncConnected, value: newValue)
            }
        }

        static var isYouTubeSyncDone: Bool {
            get {
                return get(bool: .YouTubeSyncDone)
            }
            set {
                set(bool: .YouTubeSyncDone, value: newValue)
            }
        }

        static func reset() {
            let defaults = UserDefaults.standard
            defaults.removeObject(forKey: Lbryio.Defaults.Key.EmailRewardClaimed.rawValue)
            defaults.removeObject(forKey: Lbryio.Defaults.Key.YouTubeSyncDone.rawValue)
            defaults.removeObject(forKey: Lbryio.Defaults.Key.YouTubeSyncConnected.rawValue)
        }
    }

    // - MARK: Keychain

    // Report errors but don't throw/crash, because user can just log in again

    enum KeychainError: Error {
        case noPassword
        case unexpectedPasswordData
        case unhandledError(status: OSStatus)
    }

    static func persistAuthToken() {
        guard let tokenData = Lbryio.authToken?.data else {
            Crashlytics.crashlytics().recordImmediate(
                error: GenericError("persistAuthToken nil"),
                userInfo: ["persistAuthToken_token": Lbryio.authToken as Any]
            )
            return
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrServer as String: connectionString,
            kSecValueData as String: tokenData,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            Crashlytics.crashlytics().recordImmediate(error: KeychainError.unhandledError(status: status))
            return
        }
    }

    static func loadAuthToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrServer as String: connectionString,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status != errSecItemNotFound else {
            // No need to log this when it's expected first-run behavior
            // Crashlytics.crashlytics().recordImmediate(error: KeychainError.noPassword)
            return
        }
        guard status == errSecSuccess else {
            Crashlytics.crashlytics().recordImmediate(error: KeychainError.unhandledError(status: status))
            return
        }

        guard let tokenData = item as? Data,
              let token = String(data: tokenData, encoding: .utf8)
        else {
            Crashlytics.crashlytics().recordImmediate(error: KeychainError.unexpectedPasswordData)
            return
        }

        Lbryio.authToken = token
    }

    static func deleteAuthToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrServer as String: connectionString,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            Crashlytics.crashlytics().recordImmediate(error: KeychainError.unhandledError(status: status))
            return
        }
    }

    // - MARK: Lbryio

    static var generatingAuthToken: Bool = false
    static let connectionString = "https://api.odysee.com"
    static let wsConnectionBaseUrl = "wss://api.lbry.com/subscribe?auth_token="
    static let wsCommmentBaseUrl = "wss://comments.lbry.com/api/v2/live-chat/subscribe?subscription_id="
    static let authTokenParam = "auth_token"
    static var authToken: String? {
        didSet {
            guard authToken != nil else {
                deleteAuthToken()
                return
            }
        }
    }

    static var currentUser: User?

    private static let lock = Lock()
    static var currentLbcUsdRate: Decimal? = 0
    static var followedUrls: [String] = [] // simple cache of followed urls
    static var cachedSubscriptions = [String: LbrySubscription]()
    static var cachedNotifications: [LbryNotification] = []
    static var latestNotificationId: Int64 = 0
    static var subscriptionsDirty = false

    static var appleFilteredClaimsTagged = [String: String]()
    static var appleFilteredClaimIds = Set<String>()

    static func addAppleFilteredClaim(claimId: String?, tag: String?) {
        guard let claimId = claimId, let tag = tag else { return }
        lock.withLock {
            appleFilteredClaimsTagged[claimId] = tag
        }
    }

    static func updateAppleFilteredClaimIds() {
        lock.withLock {
            appleFilteredClaimIds = Set(appleFilteredClaimsTagged.keys)
        }
    }

    static func getFilteredMessageForClaim(_ claimId: String, _ signingClaimId: String) -> String {
        let defaultText =
            "This content is not available on iOS. Consider using odysee.com for the Complete Odysee Experience."

        var tag = appleFilteredClaimsTagged[claimId]
        if tag == nil {
            tag = appleFilteredClaimsTagged[signingClaimId]
        }
        if let tagName = tag {
            switch tagName {
            case "dmca":
                return "In response to a complaint we received under the US Digital Millennium Copyright Act, we have blocked access to this content from our applications."
            case "internal-dmca-redflag":
                return "In response to a complaint we received under the US Digital Millennium Copyright Act, we have blocked access to this content from our applications."
            case "filter-ios":
                return defaultText
            default:
                return defaultText
            }
        }

        return defaultText
    }

    private static var filteredOutpoints = Set<Outpoint>()
    static func setFilteredOutpoints(_ val: Set<Outpoint>) {
        lock.withLock { filteredOutpoints = val }
    }

    private static var blockedOutpoints = Set<Outpoint>()
    static func setBlockedOutpoints(_ val: Set<Outpoint>) {
        lock.withLock { blockedOutpoints = val }
    }

    static func get(
        resource: String,
        action: String,
        options: [String: String]? = nil,
        authTokenOverride: String? = nil,
        completion: @escaping (Any?, Error?) -> Void
    ) throws {
        try call(resource: resource, action: action, options: options, method: .GET, completion: completion)
    }

    static func post(
        resource: String,
        action: String,
        options: [String: String]? = nil,
        authTokenOverride: String? = nil,
        completion: @escaping (Any?, Error?) -> Void
    ) throws {
        try call(resource: resource, action: action, options: options, method: .POST, completion: completion)
    }

    static func call(
        resource: String,
        action: String,
        options: [String: String]? = nil,
        method: Method,
        authTokenOverride: String? = nil,
        completion: @escaping (Any?, Error?) -> Void
    ) throws {
        try call(
            resource: resource,
            action: action,
            options: options,
            method: method.rawValue,
            authTokenOverride: authTokenOverride,
            completion: completion
        )
    }

    static func call(
        resource: String,
        action: String,
        options: [String: String]? = nil,
        method: String,
        authTokenOverride: String? = nil,
        completion: @escaping (Any?, Error?) -> Void
    ) throws {
        let url = "\(connectionString)/\(resource)/\(action)"
        if authToken.isBlank, !generatingAuthToken {
            // generate the auth token before calling this resource
            try getAuthToken(completion: { token, error in
                if !token.isBlank {
                    Lbryio.authToken = token
                    persistAuthToken()
                }

                // send the call after the auth token has been retrieved
                do {
                    try call(
                        resource: resource,
                        action: action,
                        options: options,
                        method: method,
                        completion: completion
                    )
                } catch {
                    completion(nil, error)
                }
            })
            return
        }

        var requestUrl = URL(string: url)
        var queryItems: [URLQueryItem] = []
        if !authToken.isBlank {
            queryItems.append(URLQueryItem(name: authTokenParam, value: authTokenOverride ?? authToken))
        }
        if let options {
            for (name, value) in options {
                queryItems.append(URLQueryItem(name: name, value: value))
            }
        }
        guard var urlComponents = URLComponents(string: url) else {
            completion(nil, GenericError("urlComponents"))
            return
        }
        urlComponents.queryItems = queryItems
        urlComponents.percentEncodedQuery = urlComponents.percentEncodedQuery?.replacingOccurrences(
            of: "+",
            with: "%2B"
        )

        if Method.GET.isEqual(toString: method) {
            requestUrl = urlComponents.url
        }

        guard let requestUrl else {
            completion(nil, GenericError("requestUrl"))
            return
        }

        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil

        let session = URLSession(configuration: config)
        var req = URLRequest(url: requestUrl)
        req.httpMethod = method
        if Method.POST.isEqual(toString: method) {
            req.httpBody = buildQueryString(authToken: authTokenOverride ?? authToken, options: options).data
        }

        let task = session.dataTask(with: req, completionHandler: { data, response, error in
            guard let data = data, error == nil else {
                // handle error
                completion(nil, error)
                return
            }
            do {
                var respCode = 0
                if let httpResponse = response as? HTTPURLResponse {
                    respCode = httpResponse.statusCode
                }
                let respData = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]

                Crashlytics.crashlytics().setCustomValue(
                    String(data: data, encoding: .utf8),
                    forKey: "Lbryio.call_data"
                )
                Crashlytics.crashlytics().setCustomValue(respCode, forKey: "Lbryio.call_respCode")

                if let string = String(data: data, encoding: .utf8) {
                    Log.verboseJSON.logIfEnabled(.debug, string)
                }

                if respCode >= 200, respCode < 300 {
                    if respData?["data"] == nil {
                        completion(true, nil)
                        return
                    }
                    completion(respData?["data"], nil)
                    return
                }

                if respData?["error"] as? NSNull != nil {
                    completion(nil, LbryioResponseError("no error message", respCode))
                } else if let error = respData?["error"] as? String {
                    completion(nil, LbryioResponseError(error, respCode))
                } else {
                    completion(nil, LbryioResponseError("Unknown api error signature", respCode))
                }
            } catch {
                completion(nil, error)
            }
        })
        task.resume()
    }

    static func buildQueryString(authToken: String?, options: [String: String]?) -> String {
        var delim = ""
        var qs = ""
        if !authToken.isBlank,
           let authToken = authToken?.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)
        {
            qs.append(authTokenParam)
            qs.append("=")
            qs.append(authToken)
            delim = "&"
        }
        if let options {
            for (name, value) in options {
                if let value = value.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) {
                    qs.append(delim)
                    qs.append(name)
                    qs.append("=")
                    qs.append(
                        value
                            .replacingOccurrences(of: "+", with: "%2B")
                            .replacingOccurrences(of: "&", with: "%26")
                            .replacingOccurrences(of: "?", with: "%3F")
                    )
                    delim = "&"
                }
            }
        }

        return qs
    }

    static func getAuthToken(completion: @escaping (String?, Error?) -> Void) throws {
        guard let installationId = Lbry.installationId, !installationId.isBlank else {
            throw LbryioRequestError.runtimeError("The installation ID is not set")
        }

        generatingAuthToken = true
        var options = [String: String]()
        options[authTokenParam] = ""
        options["language"] = "en"
        options["app_id"] = installationId

        try post(resource: "user", action: "new", options: options, completion: { data, _ in
            generatingAuthToken = false
            guard let tokenData = data as? [String: Any],
                  let token = tokenData["auth_token"] as? String,
                  !token.isBlank
            else {
                completion(nil, LbryioResponseError("auth_token was not set in the response", 0))
                return
            }
            completion(token, nil)
        })
    }

    static func isSignedIn() -> Bool {
        return currentUser != nil && !(currentUser?.primaryEmail).isEmpty
    }

    static func fetchCurrentUser(completion: @escaping (User?, Error?) -> Void) throws {
        try get(resource: "user", action: "me", completion: { data, error in
            if error != nil {
                completion(nil, error)
                return
            }

            if data != nil {
                do {
                    Crashlytics.crashlytics().setCustomValue(data as Any, forKey: "fetchCurrentUser_data")
                    let jsonData = try JSONSerialization.data(
                        withJSONObject: data as Any,
                        options: [.prettyPrinted, .sortedKeys]
                    )
                    let user: User? = try JSONDecoder().decode(User.self, from: jsonData)
                    if let user {
                        currentUser = user
                        if let id = user.id {
                            Analytics.setDefaultEventParameters([
                                "user_id": id,
                                "user_email": user.primaryEmail ?? "",
                            ])
                        }

                        completion(user, nil)
                    }
                } catch {
                    completion(nil, error)
                }
            }
        })
    }

    static func areCommentsEnabled(channelId: String, channelName: String, completion: @escaping (Bool) -> Void) {
        Lbry.commentApiCall(
            method: Lbry.CommentMethods.list,
            params: .init(
                claimId: channelId,
                channelId: channelId,
                channelName: channelName,
                page: 1,
                pageSize: 1
            )
        )
        .subscribeResult { result in
            switch result {
            case .failure:
                completion(false)
            case .success:
                completion(true)
            }
        }
    }

    static func newInstall(completion: @escaping (Error?) -> Void) {
        Messaging.messaging().token(completion: { token, error in
            if let error {
                // no need to fail on error here
                Crashlytics.crashlytics().recordImmediate(error: error)
            }

            var options = [String: String]()
            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                options["app_version"] = version
            }
            options["app_id"] = Lbry.installationId
            options["daemon_version"] = ""
            options["node_id"] = ""
            options["operating_system"] = "ios"
            options["platform"] = "darwin"
            options["domain"] = "odysee.com"
            if let token, !token.isBlank {
                options["firebase_token"] = token
            }
            do {
                try post(resource: "install", action: "new", options: options, completion: { _, error in
                    if error != nil {
                        completion(error)
                        return
                    }
                    // successful
                    completion(nil)
                })
            } catch {
                completion(error)
            }
        })
    }

    static func claimReward(type: String, walletAddress: String, completion: @escaping (Bool?, Error?) -> Void) {
        let options: [String: String] = ["reward_type": type, "wallet_address": walletAddress]
        do {
            try post(resource: "reward", action: "claim", options: options, completion: { _, error in
                if error != nil {
                    completion(false, error)
                    return
                }
                // successful
                completion(true, nil)
            })
        } catch {
            completion(false, error)
        }
    }

    static func loadExchangeRate(completion: @escaping (Decimal?, Error?) -> Void) {
        do {
            try get(resource: "lbc", action: "exchange_rate", completion: { data, error in
                guard let data = data, error == nil else {
                    completion(nil, error)
                    return
                }

                if let response = data as? [String: Any],
                   let lbcUsdRate = response["lbc_usd"] as? Double
                {
                    currentLbcUsdRate = Decimal(lbcUsdRate)
                    completion(currentLbcUsdRate, nil)
                    return
                }

                completion(nil, LbryioResponseError("exchange rate retrieval failed", 0))
            })
        } catch {
            completion(nil, error)
        }
    }

    static func syncSet(
        oldHash: String,
        newHash: String,
        data: String,
        completion: @escaping (String?, Error?) -> Void
    ) {
        var options = [String: String]()
        options["old_hash"] = oldHash
        options["new_hash"] = newHash
        options["data"] = data
        do {
            try post(resource: "sync", action: "set", options: options, completion: { data, error in
                guard let data = data, error == nil else {
                    completion(nil, error)
                    return
                }

                let response = data as? [String: Any]
                let remoteHash = response?["hash"] as? String
                completion(remoteHash, nil)
            })
        } catch {
            completion(nil, error)
        }
    }

    static func syncGet(
        hash: String,
        applySyncChanges: Bool = false,
        completion: @escaping (WalletSync?, Bool?, Error?) -> Void
    ) {
        var options = [String: String]()
        options["hash"] = hash
        do {
            try post(resource: "sync", action: "get", options: options, completion: { data, error in
                guard let response = data as? [String: Any], error == nil else {
                    if let responseError = error as? LbryioResponseError {
                        if responseError.code == 404 {
                            // no wallet found for the user, so it's a new sync
                            completion(nil, true, nil)
                            return
                        }
                    }
                    completion(nil, nil, error)
                    return
                }

                var walletSync = WalletSync()
                walletSync.hash = response["hash"] as? String
                walletSync.data = response["data"] as? String
                walletSync.changed = response["changed"] as? Bool
                completion(walletSync, false, nil)
            })
        } catch {
            completion(nil, nil, error)
        }
    }

    static func logPublishEvent(_ claimResult: Claim) {
        guard let permanentUrl = claimResult.permanentUrl,
              let claimId = claimResult.claimId,
              let txid = claimResult.txid,
              let nout = claimResult.nout
        else {
            // invalid claim or claim result, just skip
            return
        }

        do {
            var options: [String: String] = [
                "uri": permanentUrl,
                "claim_id": claimId,
                "outpoint": "\(txid):\(nout)",
            ]
            if let claimId = claimResult.signingChannel?.claimId {
                options["channel_claim_id"] = claimId
            }
            try Lbryio.post(resource: "event", action: "publish", options: options, completion: { data, error in
                guard data != nil, error == nil else {
                    // ignore errors, can always retry at a later time
                    return
                }
            })
        } catch {
            // pass
        }
    }

    static func addSubscription(sub: LbrySubscription, url: String?) {
        if let url, let url = LbryUri.tryParse(url: url, requireProto: false) {
            cachedSubscriptions[url.description] = sub
        }
    }

    static func removeSubscription(subUrl: String) {
        if let url = LbryUri.tryParse(url: subUrl, requireProto: false) {
            cachedSubscriptions.removeValue(forKey: url.description)
        }
    }

    static func isFollowing(claim: Claim) -> Bool {
        return if let permanentUrl = claim.permanentUrl,
                  let url = LbryUri.tryParse(url: permanentUrl, requireProto: false)
        {
            cachedSubscriptions[url.description] != nil
        } else {
            false
        }
    }

    static func isNotificationsDisabledForSub(claim: Claim) -> Bool {
        return if let permanentUrl = claim.permanentUrl,
                  let url = LbryUri.tryParse(url: permanentUrl, requireProto: false),
                  let sub = cachedSubscriptions[url.description]
        {
            sub.notificationsDisabled ?? true
        } else {
            true
        }
    }

    static func isClaimAppleFiltered(_ claim: Claim) -> Bool {
        guard let claimId = claim.claimId else { return false }
        return appleFilteredClaimIds.contains(claimId)
    }

    static func isClaimFiltered(_ claim: Claim) -> Bool {
        guard let outpoint = claim.outpoint else { return false }
        return lock.withLock {
            filteredOutpoints.contains(outpoint)
        }
    }

    static func isClaimBlocked(_ claim: Claim) -> Bool {
        guard let outpoint = claim.outpoint else { return false }
        return lock.withLock {
            blockedOutpoints.contains(outpoint)
        }
    }
}

enum LbryioRequestError: Error {
    case runtimeError(String)
}

struct LbryioResponseError: Error {
    let message: String
    let code: Int
    init(_ message: String, _ code: Int) {
        self.message = message
        self.code = code
    }

    var localizedDescription: String {
        return message
    }
}
