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

    /// For AccountMethods
    var method: Method = .POST

    enum Method: String {
        /// For methods that don't require authentication; can be cached by intermediate servers
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
        transform: ((inout ResultType) throws -> Void)? = nil
    ) async throws -> ResultType {
        let task = Task.detached(priority: .userInitiated) {
            let request = try Lbry.apiRequest(method: name, params: params, url: url, authToken: await AuthToken.token)

            let (data, urlResponse) = try await URLSession.shared.data(for: request)

            guard let httpResponse = urlResponse as? HTTPURLResponse else {
                throw LbryioRequestError.invalidResponse(urlResponse)
            }

            // swift-format-ignore
            print(
                "NETLOG",
                name,
                httpResponse.statusCode,
                String(data: data, encoding: .utf8)!.prefix(20).replacingOccurrences(of: "\n", with: " ")
            )

            // FIXME: All call check respcode OK before decode
            let respCode = httpResponse.statusCode
            Crashlytics.crashlytics().setCustomValue(
                String(data: data, encoding: .utf8),
                forKey: "Lbry.call_data"
            )
            Crashlytics.crashlytics().setCustomValue(respCode, forKey: "Lbry.call_respCode")

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            decoder.keyDecodingStrategy = .convertFromSnakeCase

            let response = try decoder.decode(LbryAPIResponse<ResultType>.self, from: data)
            if response.jsonrpc != "2.0" {
                assertionFailure()
                throw LbryApiResponseError("wrong jsonrpc \(response.jsonrpc)")
            }

            guard var result = response.result else {
                if name == BackendMethods.sharedPreferenceGet.name,
                   response.error?.message != "authentication required",
                   var result = SharedPreferenceGetResult(shared: nil) as? ResultType
                {
                    try defaultTransform?(&result)
                    try transform?(&result)
                    return result
                }

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
        transform: ((inout ResultType) throws -> Void)? = nil
    ) async throws -> ResultType {
        let task = Task.detached(priority: .userInitiated) {
            let request = try Lbry.apiRequest(method: name, params: params, url: url, authToken: await AuthToken.token)

            let (data, r) = try await URLSession.shared.data(for: request)

            // swift-format-ignore
            print(
                "NETLOG",
                name,
                (r as! HTTPURLResponse).statusCode,
                String(data: data, encoding: .utf8)!.prefix(20).replacingOccurrences(of: "\n", with: " ")
            )

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            decoder.keyDecodingStrategy = .convertFromSnakeCase

            let response = try decoder.decode(LbryAPIResponse<ResultType>.self, from: data)
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
    init(get name: String) {
        self.init(name: name, method: .GET)
    }

    init(post name: String) {
        self.init(name: name)
    }

    func call(params: ParamType) async throws -> ResultType {
        let url = "\(Lbryio.connectionString)/\(name)"
        guard var requestUrl = URL(string: url) else {
            throw LbryioRequestError.invalidUrl(url)
        }

        var queryItems = try QueryItemsEncoder().encode(params)

        // POST is used for methods with authentication, as the token isn't sent in the URL
        if method == .POST {
            queryItems.append(URLQueryItem(name: AccountMethods.authTokenParam, value: await AuthToken.token))
        }

        // For methods that don't require authentication, use GET and encode in the URL
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
                throw LbryioRequestError.invalidUrlComponents(components)
            }
            requestUrl = url
        }

        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil

        let session = URLSession(configuration: config)
        var req = URLRequest(url: requestUrl)
        req.httpMethod = method.rawValue

        // For methods that require authentication, use POST and encode in the request body
        if method == .POST {
            var components = URLComponents()
            components.queryItems = queryItems

            guard let query = components.percentEncodedQuery else {
                throw LbryioRequestError.invalidUrlComponents(components)
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

        // swift-format-ignore
        print(
            "NETLOG",
            name,
            httpResponse.statusCode,
            String(data: data, encoding: .utf8)!.prefix(20).replacingOccurrences(of: "\n", with: " ")
        )

        let respCode = httpResponse.statusCode

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let response = try decoder.decode(LbryioAPIResponse<ResultType>.self, from: data)

        guard let result = response.result else {
            throw LbryioResponseError.error(response.error, respCode)
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
    static let addressList = Method<NilType, AddressListResult>(name: "address_list")
    static let addressUnused = Method<NilType, String>(name: "address_unused")
    static let channelAbandon = Method<ChannelAbandonParams, Transaction>(name: "channel_abandon")
    static let channelImport = Method<ChannelImportParams, NilType>(name: "channel_import")
    static let channelSign = Method<ChannelSignParams, ChannelSignResult>(name: "channel_sign")
    static let collectionList = Method<CollectionListParams, Page<Claim>>(name: "collection_list")
    static let collectionCreate = Method<CollectionCreateParams, Transaction>(name: "collection_create")
    static let collectionUpdate = Method<CollectionUpdateParams, Transaction>(name: "collection_update")
    static let transactionList = Method<TransactionListParams, Page<Transaction>>(name: "transaction_list")
    static let txoList = Method<TxoListParams, Page<Txo>>(name: "txo_list")
    static let syncHash = Method<NilType, SyncHashResult>(name: "sync_hash")
    static let syncApply = Method<SyncApplyParams, SyncApplyResult>(name: "sync_apply")
    static let walletBalance = Method<NilType, WalletBalance>(name: "wallet_balance")

    static let sharedPreferenceGet = Method<SharedPreferenceGetParams, SharedPreferenceGetResult>(
        name: "preference_get"
    )
    static let sharedPreferenceSet = Method<SharedPreferenceSetParams, NilType>(name: "preference_set")
}

protocol CommentsMethodParams {}

enum CommentsMethods {
    struct NilType: Codable, CommentsMethodParams {}

    static let byId = Method<CommentByIdParams, CommentByIdResult>(name: "comment.ByID")
    static let list = Method<CommentListParams, Page<Comment>>(name: "comment.List")
    static let create = Method<CommentCreateParams, Comment>(name: "comment.Create")
    static let reactList = Method<CommentReactListParams, ReactListResult>(name: "reaction.List")
    static let v2_reactList = Method<CommentReactListParams, V2_ReactListResult>(name: "reaction.List")
    static let react = Method<CommentReactParams, NilType>(name: "reaction.React")
}

protocol AccountMethodParams {}

enum AccountMethods {
    static let authTokenParam = "auth_token"

    struct NilType: Codable, AccountMethodParams {}

    static let fileLastPositions = Method<FileLastPositionsParams, FileLastPositionsResult>(post: "file/last_positions")
    static let userMe = Method<NilType, User>(post: "user/me")
    static let userNew = Method<UserNewParams, UserNewResult>(get: "user/new")
    static let userExists = Method<UserExistsParams, UserExistsResult>(post: "user/exists")
    static let userSignUp = Method<UserSignInUpParams, NilType>(post: "user/signup")
    static let userSignIn = Method<UserSignInUpParams, User>(post: "user/signin")
    static let userSignOut = Method<NilType, NilType>(post: "user/signout")
    static let userEmailResendToken = Method<UserEmailResendTokenParams, NilType>(post: "user_email/resend_token")
    // FIXME: Only run on install/token change
    static let installNew = Method<InstallNewParams, NilType>(post: "install/new")
    static let syncGet = Method<SyncGetParams, SyncGetResult>(post: "sync/get")
    static let syncSet = Method<SyncSetParams, SyncSetResult>(post: "sync/set")
    static let localeGet = Method<NilType, LocaleGetResult>(get: "locale/get")
    static let geoBlockedList = Method<NilType, GeoBlockedListResult>(get: "geo/blocked_list")
    static let notificationList = Method<NotificationListParams, NotificationListResult>(post: "notification/list")
    static let notificationEdit = Method<NotificationEditParams, NilType>(post: "notification/edit")
    static let notificationDelete = Method<NotificationDeleteParams, NilType>(post: "notification/delete")
    static let subscriptionNew = Method<SubscriptionNewParams, NilType>(post: "subscription/new")
    static let subscriptionDelete = Method<SubscriptionDeleteParams, NilType>(post: "subscription/delete")
    static let viewHistory = Method<ViewHistoryParams, Page<ViewHistory>>(post: "user/view_history")
    static let viewHistoryDelete = Method<ViewHistoryDeleteParams, NilType>(post: "user/view_history/delete")
    static let viewHistoryDeleteAll = Method<NilType, NilType>(post: "user/view_history/delete")
    static let ytNew = Method<YtNewParams, String>(post: "yt/new")
    static let ytTransfer = Method<YtTransferParams, YtTransferResult>(post: "yt/transfer")

    static let ytTransferStatusCheck = Method<NilType, YtTransferResult>(post: "yt/transfer")
    static let listAppleBlockedClaimIds = Method<ListAppleBlockedClaimIdsParams, FileListClaimIdsResult>(
        get: "file/list_blocked"
    )
    static let listBlockedClaimIds = Method<FileListClaimIdsParams, FileListClaimIdsResult>(
        get: "file/list_blocked"
    )
    static let listFilteredClaimIds = Method<FileListClaimIdsParams, FileListClaimIdsResult>(
        get: "file/list_filtered"
    )
}
