//
//  APIParams.swift
//  Odysee
//
//  Created by Adlai Holler on 6/24/21.
//

import Foundation

// API taken from https://lbry.tech/api/sdk
// Structs here only contain fields that we actually use.

struct ResolveParams: Encodable {
    var urls = [String]()
}

struct StreamAbandonParams: Encodable {
    var claimId: String
    var blocking: Bool?
}

struct ClaimListParams: Encodable {
    var claimType: [ClaimType]?
    var page: Int?
    var pageSize: Int?
    var resolve: Bool?
}

struct ClaimSearchParams: Encodable {
    var claimType: [ClaimType]?
    var streamTypes: [StreamType]?
    var noTotals: Bool? = true // server defaults to false, but we dont need totals.
    var page: Int?
    var pageSize: Int?
    var releaseTime: [String]?
    var duration: String?
    var hasNoSource: Bool?
    var limitClaimsPerChannel: Int?
    var anyTags: [String]?
    var notTags: [String]?
    var channelIds: [String]?
    var notChannelIds: [String]?
    var claimIds: [String]?
    var orderBy: [String]?
}

struct AddressUnusedParams: Encodable {}

struct ChannelAbandonParams: Encodable {
    var claimId: String
    var blocking: Bool?
}

struct TransactionListParams: Encodable {
    var page: Int?
    var pageSize: Int?
}

struct TxoListParams: Encodable {
    var type: [ClaimType]?
    var txid: String?
}

struct ChannelSignParams: Encodable {
    var channelId: String
    var hexdata: String
}
