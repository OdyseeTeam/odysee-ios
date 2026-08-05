//
//  Comment.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 22/12/2020.
//

import Foundation

struct Comment: Decodable, Hashable {
    var comment: String
    var id: String
    var claimId: String
    var timestamp: Int
    var parentId: String?
    var channelId: String?
    var channelName: String?
    var channelUrl: String?
    var replies: Int?

    // MARK: Internal fields

    var numLikes: Int = 0
    var numDislikes: Int = 0
    var isLiked: Bool = false
    var isDisliked: Bool = false

    var repliesLoaded: Bool = false

    var replyDepth: Int = 1

    private enum CodingKeys: String, CodingKey {
        case comment
        case id = "comment_id"
        case claimId = "claim_id"
        case timestamp
        case parentId = "parent_id"
        case channelId = "channel_id"
        case channelName = "channel_name"
        case channelUrl = "channel_url"
        case replies
    }

    static func == (lhs: Comment, rhs: Comment) -> Bool {
        return lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        id.hash(into: &hasher)
    }
}
