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
