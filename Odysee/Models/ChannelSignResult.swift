//
//  ChannelSignResult.swift
//  Odysee
//
//  Created by Keith Toh on 11/07/2022.
//

import Foundation

struct ChannelSignResult: Decodable {
    var signature: String
    var signingTs: String

    enum CodingKeys: String, CodingKey {
        case signature
        case signingTs = "signing_ts"
    }
}
