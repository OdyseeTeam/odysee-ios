//
//  CommentAPIParams.swift
//  Odysee
//
//  Created by Keith Toh on 11/07/2022.
//

import Foundation

struct CommentListParams: Encodable {
    var claimId: String
    var channelId: String?
    var channelName: String?
    var parentId: String?
    var page: Int?
    var pageSize: Int?
    var skipValidation: Bool?
    var topLevel: Bool? = true
}

struct CommentCreateParams: Encodable {
    var claimId: String
    var channelId: String
    var signature: String
    var signingTs: String
    var comment: String
    var parentId: String?
}

struct CommentReactParams: Encodable {
    var commentIds: String
    var signature: String
    var signingTs: String
    var remove: Bool?
    var clearTypes: String?
    var type: String
    var channelId: String
    var channelName: String
}

struct CommentReactListParams: Encodable {
    var commentIds: String
    var channelName: String?
    var channelId: String?
    var signature: String
    var signingTs: String
}
