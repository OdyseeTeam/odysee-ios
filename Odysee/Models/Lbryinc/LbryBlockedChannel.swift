//
//  LbryBlockedChannel.swift
//  Odysee
//
//  Created by Keith Toh on 09/12/2025.
//

import Foundation

struct LbryBlockedChannel: Decodable, Equatable {
    var claimId: String?
    var name: String?

    private enum CodingKeys: String, CodingKey {
        case claimId = "claim_id"
    }
}
