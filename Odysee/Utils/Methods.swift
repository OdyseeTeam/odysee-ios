//
//  Methods.swift
//  Odysee
//
//  Created by Keith Toh on 18/12/2025.
//

import FirebaseCrashlytics
import Foundation

struct Method<ParamType: Encodable, ResultType: Decodable> {
    var name: String
    var defaultTransform: ((inout ResultType) throws -> Void)?

    // For Lbryio
    var method: Method = .POST

    enum Method: String {
        case GET
        case POST
    }

    struct APIError: Decodable {
        var code: Int
        var message: String
    }

    struct LbryAPIResponse<Wrapped: Decodable>: Decodable {
        var jsonrpc: String
        var error: APIError?
        var result: Wrapped?
    }

    struct LbryioAPIResponse<Wrapped: Decodable>: Decodable {
        var result: Wrapped?
        var error: String?

        enum CodingKeys: String, CodingKey {
            case result = "data"
            case error
        }
    }
}

extension Method where ParamType: BackendMethodParams {
    func call(
        params: ParamType,
        url: URL = Lbry.lbrytvURL,
        authToken: String? = nil,
        transform: ((inout ResultType) throws -> Void)? = nil
    ) async throws -> ResultType {
        let authToken = authToken != nil ? authToken : await AuthToken.token

        let task = Task.detached(priority: .userInitiated) {
            let request = try Lbry.apiRequest(method: name, params: params, url: url, authToken: authToken)

            let (data, _) = try await URLSession.shared.data(for: request)

            let response = try JSONDecoder().decode(LbryAPIResponse<ResultType>.self, from: data)
            if response.jsonrpc != "2.0" {
                assertionFailure()
                throw LbryApiResponseError("wrong jsonrpc \(response.jsonrpc)")
            }

            guard var result = response.result else {
                throw LbryApiResponseError(response.error?.message ?? "unknown api error")
            }

            try defaultTransform?(&result)
            try transform?(&result)

            return result
        }

        return try await task.value
    }
}

extension Method where ParamType: CommentsMethodParams {
    func call(
        params: ParamType,
        url: URL = Lbry.commentronURL,
        authToken: String? = nil,
        transform: ((inout ResultType) throws -> Void)? = nil
    ) async throws -> ResultType {
        let authToken = authToken != nil ? authToken : await AuthToken.token

        let task = Task.detached(priority: .userInitiated) {
            let request = try Lbry.apiRequest(method: name, params: params, url: url, authToken: authToken)

            let (data, _) = try await URLSession.shared.data(for: request)

            let response = try JSONDecoder().decode(LbryAPIResponse<ResultType>.self, from: data)
            if response.jsonrpc != "2.0" {
                assertionFailure()
                throw LbryApiResponseError("wrong jsonrpc \(response.jsonrpc)")
            }

            guard var result = response.result else {
                throw LbryApiResponseError(response.error?.message ?? "unknown api error")
            }

            try transform?(&result)

            return result
        }

        return try await task.value
    }
}

extension Method where ParamType: AccountMethodParams {
    func call(
        params: ParamType,
        authTokenOverride: String? = nil,
    ) async throws -> ResultType {
        // Intentionally allow blank for calls that need it
        let authToken = authTokenOverride != nil ? authTokenOverride : await AuthToken.token

        let url = "\(Lbryio.connectionString)/\(name)"
        guard var requestUrl = URL(string: url) else {
            throw LbryioRequestError.invalidUrl(url)
        }

        var queryItems = try QueryItemsEncoder().encode(params)
        queryItems.append(URLQueryItem(name: Lbryio.authTokenParam, value: authToken))

        if method == .GET {
            guard var components = URLComponents(string: url) else {
                throw LbryioRequestError.invalidUrl(url)
            }
            components.queryItems = queryItems
            components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(
                of: "+",
                with: "%2B"
            )

            guard let url = components.url else {
                throw LbryioRequestError.invalidUrl(components: components)
            }
            requestUrl = url
        }

        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil

        let session = URLSession(configuration: config)
        var req = URLRequest(url: requestUrl)
        req.httpMethod = method.rawValue

        if method == .POST {
            var components = URLComponents()
            components.queryItems = queryItems

            guard let query = components.percentEncodedQuery else {
                throw LbryioRequestError.invalidUrl(components: components)
            }
            req.httpBody = query.replacingOccurrences(
                of: "+",
                with: "%2B"
            ).data
        }

        let (data, urlResponse) = try await session.data(for: req)

        guard let httpResponse = urlResponse as? HTTPURLResponse else {
            throw LbryioRequestError.invalidResponse(urlResponse)
        }

        let respCode = httpResponse.statusCode
        Crashlytics.crashlytics().setCustomValue(
            String(data: data, encoding: .utf8),
            forKey: "Lbryio.call_data"
        )
        Crashlytics.crashlytics().setCustomValue(respCode, forKey: "Lbryio.call_respCode")

        let response = try JSONDecoder().decode(LbryioAPIResponse<ResultType>.self, from: data)

        guard let result = response.result else {
            throw LbryioResponseError(response.error ?? "unknown api error", respCode)
        }

        return result
    }
}

protocol BackendMethodParams {}

enum BackendMethods {
    struct NilType: Codable, BackendMethodParams {}

    static let resolve = Method<ResolveParams, ResolveResult>(
        name: "resolve",
        defaultTransform: Lbry.processResolvedClaims
    )
    static let claimSearch = Method<ClaimSearchParams, Page<Claim>>(
        name: "claim_search",
        defaultTransform: Lbry.processPageOfClaims
    )
    static let claimList = Method<ClaimListParams, Page<Claim>>(
        name: "claim_list",
        defaultTransform: Lbry.processPageOfClaims
    )
    static let streamAbandon = Method<StreamAbandonParams, Transaction>(name: "stream_abandon")
    static let addressUnused = Method<NilType, String>(name: "address_unused")
    static let channelAbandon = Method<ChannelAbandonParams, Transaction>(name: "channel_abandon")
    static let channelSign = Method<ChannelSignParams, ChannelSignResult>(name: "channel_sign")
    static let transactionList = Method<TransactionListParams, Page<Transaction>>(name: "transaction_list")
    static let txoList = Method<TxoListParams, Page<Txo>>(name: "txo_list")
    static let syncHash = Method<NilType, SyncHashResult>(name: "sync_hash")
}

protocol CommentsMethodParams {}

enum CommentsMethods {
    struct NilType: Codable, CommentsMethodParams {}

    static let byId = Method<CommentByIdParams, CommentByIdResult>(name: "comment.ByID")
    static let list = Method<CommentListParams, Page<Comment>>(name: "comment.List")
    static let create = Method<CommentCreateParams, Comment>(name: "comment.Create")
    static let reactList = Method<CommentReactListParams, ReactListResult>(name: "reaction.List")
    static let react = Method<CommentReactParams, NilType>(name: "reaction.React")
}

protocol AccountMethodParams {}

enum AccountMethods {
    struct NilType: Codable, AccountMethodParams {}

    static let userNew = Method<UserNewParams, UserNewResult>(name: "user/new")
}
