//
//  APIParams.swift
//  Odysee
//
//  Created by Adlai Holler on 6/24/21.
//

import Foundation

struct ResolveParams: Encodable {
    var urls = [String]()
}

struct CommentListParams: Encodable {
    var claimId: String
    var channelId: String?
    var channelName: String?
    var page: Int?
    var pageSize: Int?
    var skipValidation: Bool?
    var includeReplies: Bool?
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
    var noTotals: Bool? = true // server defaults to false, but we dont need totals.
    var page: Int?
    var pageSize: Int?
    var releaseTime: String?
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
