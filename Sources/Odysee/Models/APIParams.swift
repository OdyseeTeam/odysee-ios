//
//  APIParams.swift
//  Odysee
//
//  Created by Adlai Holler on 6/24/21.
//

import Foundation

// API taken from https://lbry.tech/api/sdk
// Structs here only contain fields that we actually use.

public struct ResolveParams: Encodable {
    public var urls = [String]()
    
    public init(urls: [String] = [String]()) {
        self.urls = urls
    }
}

public struct StreamAbandonParams: Encodable {
    public var claimId: String
    public var blocking: Bool?
    
    public init(claimId: String, blocking: Bool? = nil) {
        self.claimId = claimId
        self.blocking = blocking
    }
}

public struct ClaimListParams: Encodable {
    
    public var claimType: [ClaimType]?
    public var page: Int?
    public var pageSize: Int?
    public var resolve: Bool?
    
    public init(claimType: [ClaimType]? = nil, page: Int? = nil, pageSize: Int? = nil, resolve: Bool? = nil) {
        self.claimType = claimType
        self.page = page
        self.pageSize = pageSize
        self.resolve = resolve
    }
}

public struct ClaimSearchParams: Encodable {
    public var claimType: [ClaimType]?
    public var streamTypes: [StreamType]?
    public var noTotals: Bool? = true // server defaults to false, but we dont need totals.
    public var page: Int?
    public var pageSize: Int?
    public var releaseTime: [String]?
    public var duration: String?
    public var hasNoSource: Bool?
    public var limitClaimsPerChannel: Int?
    public var anyTags: [String]?
    public var notTags: [String]?
    public var channelIds: [String]?
    public var notChannelIds: [String]?
    public var claimIds: [String]?
    public var orderBy: [String]?
    
    public init(claimType: [ClaimType]? = nil, streamTypes: [StreamType]? = nil, noTotals: Bool? = nil, page: Int? = nil, pageSize: Int? = nil, releaseTime: [String]? = nil, duration: String? = nil, hasNoSource: Bool? = nil, limitClaimsPerChannel: Int? = nil, anyTags: [String]? = nil, notTags: [String]? = nil, channelIds: [String]? = nil, notChannelIds: [String]? = nil, claimIds: [String]? = nil, orderBy: [String]? = nil) {
        self.claimType = claimType
        self.streamTypes = streamTypes
        self.noTotals = noTotals
        self.page = page
        self.pageSize = pageSize
        self.releaseTime = releaseTime
        self.duration = duration
        self.hasNoSource = hasNoSource
        self.limitClaimsPerChannel = limitClaimsPerChannel
        self.anyTags = anyTags
        self.notTags = notTags
        self.channelIds = channelIds
        self.notChannelIds = notChannelIds
        self.claimIds = claimIds
        self.orderBy = orderBy
    }
}

public struct AddressUnusedParams: Encodable {
    
    public init() { }
}

public struct ChannelAbandonParams: Encodable {
    public var claimId: String
    public var blocking: Bool?
    
    public init(claimId: String, blocking: Bool? = nil) {
        self.claimId = claimId
        self.blocking = blocking
    }
}

public struct TransactionListParams: Encodable {
    public var page: Int?
    public var pageSize: Int?
    
    public init(page: Int? = nil, pageSize: Int? = nil) {
        self.page = page
        self.pageSize = pageSize
    }
}

public struct TxoListParams: Encodable {
    public var type: [ClaimType]?
    public var txid: String?
    
    public init(type: [ClaimType]? = nil, txid: String? = nil) {
        self.type = type
        self.txid = txid
    }
}

public struct ChannelSignParams: Encodable {
    public var channelId: String
    public var hexdata: String
    
    public init(channelId: String, hexdata: String) {
        self.channelId = channelId
        self.hexdata = hexdata
    }
}
