//
//  CommentsAPIParams.swift
//  Odysee
//
//  Created by Keith Toh on 11/07/2022.
//

import Foundation

struct CommentByIdParams: Encodable, CommentsMethodParams {
    var commentId: String
    var withAncestors: Bool?
}

// FIXME: Match ListArgs
struct CommentListParams: Encodable, CommentsMethodParams {
    var claimId: String
    var channelId: String?
    var channelName: String?
    var parentId: String?
    var page: Int
    var pageSize: Int
    var topLevel: Bool
    var sortBy: Sort

    enum Sort: Int, Encodable {
        case newest
        case oldest
        case controversy
        case popularity
        case newestNoPins
    }
}

struct CommentCreateParams: Encodable, CommentsMethodParams {
    var claimId: String
    var channelId: String
    var signature: String
    var signingTs: String
    var comment: String
    var parentId: String?
}

struct CommentReactParams: Encodable, CommentsMethodParams {
    var commentIds: String
    var signature: String
    var signingTs: String
    var remove: Bool?
    var clearTypes: String?
    var type: String
    var channelId: String
    var channelName: String
}

struct CommentReactListParams: Encodable, CommentsMethodParams {
    var commentIds: String
    var channelName: String?
    var channelId: String?
    var signature: String?
    var signingTs: String?
}
