//
//  ChannelSignResult.swift
//  Odysee
//
//  Created by Keith Toh on 11/07/2022.
//

import Foundation

public struct ChannelSignResult: Decodable, Hashable {
    
    public var signature: String
    public var signingTs: String

    enum CodingKeys: String, CodingKey {
        case signature
        case signingTs = "signing_ts"
    }
}
