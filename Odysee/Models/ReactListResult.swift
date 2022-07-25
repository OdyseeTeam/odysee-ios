//
//  ReactListResult.swift
//  Odysee
//
//  Created by Keith Toh on 13/07/2022.
//

import Foundation

struct ReactListResult: Decodable {
    struct Reaction: Decodable {
        var like: Int
        var dislike: Int
    }

    var othersReactions: [String: Reaction]?
    var myReactions: [String: Reaction]?

    enum CodingKeys: String, CodingKey {
        case othersReactions = "others_reactions"
        case myReactions = "my_reactions"
    }
}
