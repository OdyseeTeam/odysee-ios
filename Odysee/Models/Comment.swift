//
//  Comment.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 22/12/2020.
//

import Foundation

struct Comment: Decodable, Hashable {
    var channelId: String?
    var channelName: String?
    var channelUrl: String?
    var claimId: String?
    var parentId: String?
    var comment: String?
    var commentId: String?
    var isChannelSignatureValid: Bool?
    var isHidden: Bool?
    var isPinned: Bool?
    var replies: Int?
    var signature: String?
    var signingTs: String?
    var timestamp: Int64?

    var numLikes: Int?
    var numDislikes: Int?
    var isLiked: Bool?
    var isDisliked: Bool?

    var repliesLoaded: Bool?

    private enum CodingKeys: String, CodingKey {
        case channelId = "channel_id"
        case channelName = "channel_name"
        case channelUrl = "channel_url"
        case claimId = "claim_id"
        case parentId = "parent_id"
        case comment
        case commentId = "comment_id"
        case isChannelSignatureValid = "is_channel_signature_valid"
        case isHidden = "is_hidden"
        case isPinned = "is_pinned"
        case replies
        case signature
        case signingTs = "signing_ts"
        case timestamp
    }

    static func == (lhs: Comment, rhs: Comment) -> Bool {
        return lhs.commentId == rhs.commentId
    }

    func hash(into hasher: inout Hasher) {
        commentId.hash(into: &hasher)
    }
}
