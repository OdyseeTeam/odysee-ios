//
//  Comment.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 22/12/2020.
//

import Foundation

struct Comment: Decodable, Hashable, Identifiable {
    var comment: String
    var id: String
    var claimId: String
    var timestamp: TimeInterval
    var parentId: String?
    var channelId: String?
    var channelName: String?
    var channelUrl: String?
    var replyCount: Int?

    // MARK: Internal fields

    var numLikes: Int = 0
    var numDislikes: Int = 0
    var isLiked: Bool = false
    var isDisliked: Bool = false

    // FIXME: Remove (Not needed in SwiftUI component)
    var repliesLoaded: Bool = false

    // FIXME: Remove (Not needed in SwiftUI component)
    var replyDepth: Int = 1

    // FIXME: Remove (Not needed in SwiftUI component)
    var replies: [Comment] = []

    private enum CodingKeys: String, CodingKey {
        case comment
        case id = "comment_id"
        case claimId = "claim_id"
        case timestamp
        case parentId = "parent_id"
        case channelId = "channel_id"
        case channelName = "channel_name"
        case channelUrl = "channel_url"
        case replyCount = "replies"
    }

    func hash(into hasher: inout Hasher) {
        id.hash(into: &hasher)
    }
}
