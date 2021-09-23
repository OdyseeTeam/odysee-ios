//
//  RewardVerified.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 18/12/2020.
//

import Foundation

struct RewardVerified: Decodable {
    var userId: Int64?
    var isRewardApproved: Bool?

    private enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case isRewardApproved = "is_reward_approved"
    }
}
