//
//  Lbry.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 02/11/2020.
//

import Base58Swift
import Combine
import CryptoKit
import Foundation
import os
import UIKit

enum Lbry {
    // swift-format-ignore
    // Initialized once with static value
    static let lbrytvURL = URL(string: "https://api.na-backend.odysee.com/api/v1/proxy")!
    // swift-format-ignore
    // Initialized once with static value
    static let uploadURL = URL(string: "https://publish.na-backend.odysee.com/v1")!
    // swift-format-ignore
    // Initialized once with static value
    static let commentronURL = URL(string: "https://comments.odysee.tv/api/v2")!

    static func processResolvedClaims(_ result: inout ResolveResult) {
        // if there was only one value returned, this is a result for the File view
        // Filtering will be handled on the file view instead
        if result.claims.keys.count > 1 {
            result.claims = result.claims.filter {
                !Lbryio.isClaimBlocked($0.value) &&
                    !Lbryio.isClaimAppleFiltered($0.value) &&
                    !Lbryio.isClaimFiltered($0.value)
            }
            result.claims = result.claims
                .filter {
                    !Lbryio.isClaimBlocked($0.value.signingChannel ?? Claim()) &&
                        !Lbryio.isClaimAppleFiltered($0.value.signingChannel ?? Claim()) &&
                        !Lbryio.isClaimFiltered($0.value.signingChannel ?? Claim())
                }
        }
        result.claims.values.forEach(Lbry.addClaimToCache)
    }

    static func processPageOfClaims(_ page: inout Page<Claim>) {
        page.items
            .removeAll { Lbryio.isClaimBlocked($0) || Lbryio.isClaimFiltered($0) || Lbryio.isClaimAppleFiltered($0) }
        page.items
            .removeAll {
                Lbryio.isClaimBlocked($0.signingChannel ?? Claim()) || Lbryio
                    .isClaimFiltered($0.signingChannel ?? Claim()) || Lbryio
                    .isClaimAppleFiltered($0.signingChannel ?? Claim())
            }
        page.items.forEach(Lbry.addClaimToCache)
    }

    // Over time these will move up into the Methods struct as we migrate to the newer apiCall func.
    static let methodChannelCreate = "channel_create"
    static let methodChannelUpdate = "channel_update"
    static let methodStreamUpdate = "stream_update"
    static let methodGet = "get"
    static let methodPublish = "publish"
    static let methodPreferenceGet = "preference_get"
    static let methodPreferenceSet = "preference_set"
    static let methodSupportCreate = "support_create"
    static let methodSyncHash = "sync_hash"
    static let methodSyncApply = "sync_apply"
    static let methodWalletBalance = "wallet_balance"
    static let methodWalletStatus = "wallet_status"
    static let methodWalletUnlock = "wallet_unlock"
    static let methodWalletSend = "wallet_send"

    static var installationId: String?
    static let keyInstallationId = "AppInstallationId"

    static var remoteWalletHash: String?
    static var localWalletHash: String?
    static var walletBalance: WalletBalance?

    private static var claimCacheById = NSCache<NSString, Box<Claim>>()
    private static var claimCacheByUrl = NSCache<NSString, Box<Claim>>()
    static var ownChannels: [Claim] = []
    static var ownUploads: [Claim] = []
    static var defaultChannelId: String?

    private struct APIBody<CallParams: Encodable>: Encodable {
        var method: String
        var params: CallParams
        var jsonrpc = "2.0"
        var id = Int64(Date().timeIntervalSince1970)
    }

    private static let bodyEncoder: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        return e
    }()

    static func apiRequest<Params: Encodable>(
        method: String,
        params: Params,
        url: URL,
        authToken: String?
    ) throws -> URLRequest {
        let body = APIBody(method: method, params: params)

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        do {
            req.httpBody = if method == BackendMethods.sharedPreferenceSet.name {
                try JSONEncoder().encode(body)
            } else {
                try bodyEncoder.encode(body)
            }
        } catch {
            assertionFailure("API encoding error: \(error)")
            throw error
        }
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.addValue("application/json", forHTTPHeaderField: "Accept")
        if let authToken = authToken, !authToken.isBlank {
            req.addValue(authToken, forHTTPHeaderField: "X-Lbry-Auth-Token")
        }
        return req
    }

    struct APIError: Decodable {
        var code: Int
        var message: String
    }

    struct APIResponse<Wrapped: Decodable>: Decodable {
        var jsonrpc: String
        var error: APIError?
        var result: Wrapped?
    }

    // `transform` is run off-main to do things like sorting/filtering. Be cafeful!
    // The returned publisher receives events on the main thread.
    static func commentApiCall<Params: Encodable, ResultType: Decodable>
    (
        method: Method<Params, ResultType>,
        params: Params,
        url: URL = commentronURL,
        transform: ((inout ResultType) throws -> Void)? = nil
    )
        -> AnyPublisher<ResultType, Error>
    {
        return apiCall(method: method, params: params, url: url, transform: transform)
    }

    // `transform` is run off-main to do things like sorting/filtering. Be cafeful!
    // The returned publisher receives events on the main thread.
    static func apiCall<Params: Encodable, ResultType: Decodable>
    (
        method: Method<Params, ResultType>,
        params: Params,
        url: URL = lbrytvURL,
        authTokenOverride: String? = nil,
        transform: ((inout ResultType) throws -> Void)? = nil
    )
        -> AnyPublisher<ResultType, Error>
    {
        // Note: We subscribe on global queue to do encoding etc. off the main thread.
        return Just(()).subscribe(on: DispatchQueue.global()).flatMap {
            Future { promise in
                Task {
                    let authToken = authTokenOverride != nil ? authTokenOverride : await AuthToken.token

                    do {
                        // Create URLRequest.
                        try promise(.success(
                            apiRequest(method: method.name, params: params, url: url, authToken: authToken)
                        ))
                    } catch {
                        promise(.failure(error))
                    }
                }
            }
        }
        .flatMap { request in
            // Run data task.
            URLSession.shared.dataTaskPublisher(for: request).mapError { $0 as Error }
        }
        .tryMap { data, _ -> ResultType in
            // Decode and validate result.
            let response = try JSONDecoder().decode(APIResponse<ResultType>.self, from: data)
            if response.jsonrpc != "2.0" {
                assertionFailure()
                throw LbryApiResponseError("wrong jsonrpc \(response.jsonrpc)")
            }

            guard var result = response.result else {
                throw LbryApiResponseError(response.error?.message ?? "unknown api error")
            }
            try method.defaultTransform?(&result)
            try transform?(&result)
            return result
        }
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }

    // Delivers the result on a background thread as a [String: Any].
    // New code should migrate to the version above that delivers on main.
    static func apiCall(
        method: String,
        params: [String: Any],
        url: URL,
        authTokenOverride: String? = nil,
        completion: @escaping ([String: Any]?, Error?) -> Void
    ) {
        Task {
            // Intentionally allow blank for calls that need it
            let authToken = authTokenOverride != nil ? authTokenOverride : await AuthToken.token

            let req: URLRequest
            do {
                req = try apiRequest(
                    method: method,
                    params: params as NSDictionary,
                    url: url,
                    authToken: authToken
                )
            } catch {
                completion(nil, error)
                return
            }
            let task = URLSession.shared.dataTask(with: req, completionHandler: { data, _, error in
                guard let data = data, error == nil else {
                    // handle error
                    completion(nil, error)
                    return
                }
                do {
                    Log.verboseJSON.logIfEnabled(
                        .debug,
                        "Response to `\(method)`: \(String(data: data, encoding: .utf8) ?? "Couldn't parse data")"
                    )

                    let response = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                    if response?["result"] != nil {
                        completion(response, nil)
                    } else {
                        if response?["error"] == nil, response?["result"] == nil {
                            completion(nil, nil)
                        } else if let error = response?["error"] as? String {
                            completion(nil, LbryApiResponseError(error))
                        } else if let errorJson = response?["error"] as? [String: Any],
                                  let errorMessage = errorJson["message"] as? String
                        {
                            completion(nil, LbryApiResponseError(errorMessage))
                        } else {
                            completion(nil, LbryApiResponseError("unknown api error"))
                        }
                    }
                } catch {
                    completion(nil, error)
                }
            })
            task.resume()
        }
    }

    static func cachedClaim(url: String) -> Claim? {
        return claimCacheByUrl.object(forKey: url as NSString)?.wrappedValue
    }

    static func cachedClaim(id: String) -> Claim? {
        return claimCacheById.object(forKey: id as NSString)?.wrappedValue
    }

    static func addClaimToCache(claim: Claim?) {
        guard let claim = claim else {
            return
        }
        assert(claim.claimId != nil)

        let boxed = Box(claim)

        if let id = claim.claimId {
            claimCacheById.setObject(boxed, forKey: id as NSString)
        }
        if let claimUrl = claim.permanentUrl,
           let parsed = LbryUri.tryParse(url: claimUrl, requireProto: false)?.description
        {
            Lbry.claimCacheByUrl.setObject(boxed, forKey: parsed as NSString)
        }
        if let shortUrl = claim.shortUrl, !shortUrl.isBlank {
            Lbry.claimCacheByUrl.setObject(boxed, forKey: shortUrl as NSString)
        }
        if let canonicalUrl = claim.canonicalUrl, !canonicalUrl.isBlank {
            Lbry.claimCacheByUrl.setObject(boxed, forKey: canonicalUrl as NSString)
        }
    }

    static func generateId() -> String? {
        return generateId(numBytes: 64)
    }

    static func generateId(numBytes: Int) -> String? {
        var data = Data(count: numBytes)
        let result = data.withUnsafeMutableBytes {
            // swift-format-ignore
            // All of this is unsafe
            SecRandomCopyBytes(kSecRandomDefault, numBytes, $0.baseAddress!)
        }
        if result == errSecSuccess {
            let hash = SHA384.hash(data: data)
            return Base58.base58Encode(Array(hash.makeIterator()))
        }
        return nil
    }
}

struct LbryApiResponseError: LocalizedError {
    let message: String
    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? {
        return message
    }
}
