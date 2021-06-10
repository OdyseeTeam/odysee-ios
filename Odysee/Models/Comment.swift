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
        case channelId = "channel_id", channelName = "channel_name", channelUrl = "channel_url", claimId = "claim_id", parentId = "parent_id", comment = "comment", commentId = "comment_id", isChannelSignatureValid = "is_channel_signature_valid", isHidden = "is_hidden", isPinned = "is_pinned", replies = "replies", signature = "signature", signingTs = "signing_ts", timestamp = "timestamp"
    }
    
    static func ==(lhs: Comment, rhs: Comment) -> Bool {
        return lhs.commentId == rhs.commentId
    }
    func hash(into hasher: inout Hasher) {
        commentId.hash(into: &hasher)
    }
}
