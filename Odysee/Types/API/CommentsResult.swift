//
//  CommentsResult.swift
//  Odysee
//
//  Created by Keith Toh on 13/07/2022.
//

import Foundation

struct CommentByIdResult: Decodable {
    var comment: Comment?
    var ancestors: [Comment]?

    enum CodingKeys: String, CodingKey {
        case comment = "items"
        case ancestors
    }
}

struct ReactListResult: Decodable {
    struct Reaction: Decodable {
        var like: Int
        var dislike: Int
    }

    var othersReactions: [String: Reaction]
    var myReactions: [String: Reaction]?

    enum CodingKeys: String, CodingKey {
        case othersReactions = "others_reactions"
        case myReactions = "my_reactions"
    }
}

/// Decodes from API directly to like/dislike count + "my" reactions
struct V2_ReactListResult: Decodable {
    /// Dict mapping `comment_id` to reactions
    var reactions: [Comment.ID: CommentReactions]

    private struct Reaction: Decodable {
        var like: Int
        var dislike: Int
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let othersReactions = try container.decode([String: Reaction].self, forKey: .othersReactions)
        reactions = othersReactions.mapValues { reaction in
            .init(numLikes: reaction.like, numDislikes: reaction.dislike)
        }

        if let myReactions = try container.decodeIfPresent([String: Reaction].self, forKey: .myReactions) {
            for (id, reaction) in myReactions {
                reactions[id]?.numLikes += reaction.like
                reactions[id]?.numDislikes += reaction.dislike
                reactions[id]?.isLiked = reaction.like > 0
                reactions[id]?.isDisliked = reaction.dislike > 0
            }
        }
    }

    enum CodingKeys: String, CodingKey {
        case othersReactions = "others_reactions"
        case myReactions = "my_reactions"
    }
}
