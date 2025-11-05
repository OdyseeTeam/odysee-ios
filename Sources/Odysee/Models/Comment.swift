//
//  Comment.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 22/12/2020.
//

import Foundation

public struct Comment: Decodable, Hashable {
    
    public var channelId: String?
    public var channelName: String?
    public var channelUrl: String?
    public var claimId: String?
    public var parentId: String?
    public var comment: String?
    public var commentId: String?
    public var isChannelSignatureValid: Bool?
    public var isHidden: Bool?
    public var isPinned: Bool?
    public var replies: Int?
    public var signature: String?
    public var signingTs: String?
    public var timestamp: Int64?
    
    public var numLikes: Int?
    public var numDislikes: Int?
    public var isLiked: Bool?
    public var isDisliked: Bool?

    public var repliesLoaded: Bool?
    
    public init(channelId: String? = nil, channelName: String? = nil, channelUrl: String? = nil, claimId: String? = nil, parentId: String? = nil, comment: String? = nil, commentId: String? = nil, isChannelSignatureValid: Bool? = nil, isHidden: Bool? = nil, isPinned: Bool? = nil, replies: Int? = nil, signature: String? = nil, signingTs: String? = nil, timestamp: Int64? = nil, numLikes: Int? = nil, numDislikes: Int? = nil, isLiked: Bool? = nil, isDisliked: Bool? = nil, repliesLoaded: Bool? = nil) {
        self.channelId = channelId
        self.channelName = channelName
        self.channelUrl = channelUrl
        self.claimId = claimId
        self.parentId = parentId
        self.comment = comment
        self.commentId = commentId
        self.isChannelSignatureValid = isChannelSignatureValid
        self.isHidden = isHidden
        self.isPinned = isPinned
        self.replies = replies
        self.signature = signature
        self.signingTs = signingTs
        self.timestamp = timestamp
        self.numLikes = numLikes
        self.numDislikes = numDislikes
        self.isLiked = isLiked
        self.isDisliked = isDisliked
        self.repliesLoaded = repliesLoaded
    }

    enum CodingKeys: String, CodingKey {
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
}
