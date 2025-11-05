//
//  ReactListResult.swift
//  Odysee
//
//  Created by Keith Toh on 13/07/2022.
//

import Foundation

public struct ReactListResult: Decodable, Hashable {

    public var othersReactions: [String: Reaction]?
    public var myReactions: [String: Reaction]?

    enum CodingKeys: String, CodingKey {
        case othersReactions = "others_reactions"
        case myReactions = "my_reactions"
    }
}

public extension ReactListResult {
    
    struct Reaction: Decodable, Hashable {
        
        public var like: Int
        public var dislike: Int
    }
}
