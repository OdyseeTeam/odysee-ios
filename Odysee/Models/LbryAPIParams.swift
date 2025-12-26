//
//  LbryAPIParams.swift
//  Odysee
//
//  Created by Adlai Holler on 6/24/21.
//

import Foundation

// API taken from https://lbry.tech/api/sdk
// Structs here only contain fields that we actually use.

struct ResolveParams: Encodable, LbryMethodParams {
    var urls = [String]()
}

struct StreamAbandonParams: Encodable, LbryMethodParams {
    var claimId: String
    var blocking: Bool?
}

struct ClaimListParams: Encodable, LbryMethodParams {
    var claimType: [ClaimType]?
    var page: Int?
    var pageSize: Int?
    var resolve: Bool?
}

struct ClaimSearchParams: Encodable, LbryMethodParams {
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

struct ChannelAbandonParams: Encodable, LbryMethodParams {
    var claimId: String
    var blocking: Bool?
}

struct TransactionListParams: Encodable, LbryMethodParams {
    var page: Int?
    var pageSize: Int?
}

struct TxoListParams: Encodable, LbryMethodParams {
    var type: [ClaimType]?
    var txid: String?
}

struct ChannelSignParams: Encodable, LbryMethodParams {
    var channelId: String
    var hexdata: String
}

struct SyncApplyParams: Encodable, LbryMethodParams {
    let password: String = ""
    var data: String?
    var blocking: Bool = false
}

let PreferenceKeyShared = "shared"

struct SharedPreferenceGetParams: Encodable, LbryMethodParams {
    let key: String = PreferenceKeyShared
}

struct SharedPreferenceSetParams: Encodable, LbryMethodParams {
    let key: String = PreferenceKeyShared
    var value: SharedPreference
}
