//
//  Lbry.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 02/11/2020.
//

import Combine
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
                ClaimFiltering.reason(for: $0.value) == nil
            }
        }
    }

    static func processPageOfClaims(_ page: inout Page<Claim>) {
        page.items.removeAll {
            ClaimFiltering.reason(for: $0) != nil
        }
    }

    // Over time these will move up into the Methods struct as we migrate to the newer apiCall func.
    static let methodChannelCreate = "channel_create"
    static let methodChannelUpdate = "channel_update"
    static let methodStreamUpdate = "stream_update"
    static let methodGet = "get"
    static let methodPublish = "publish"
    static let methodSupportCreate = "support_create"
    static let methodWalletSend = "wallet_send"

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
}

struct LbryApiResponseError: LocalizedError, CustomNSError {
    let message: String
    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String {
        return message
    }

    var errorUserInfo: [String: Any] {
        [NSLocalizedDescriptionKey: errorDescription]
    }
}
