//
//  RewardVerified.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 18/12/2020.
//

import Foundation

public struct RewardVerified: Decodable {
    
    public var userId: Int64?
    public var isRewardApproved: Bool?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case isRewardApproved = "is_reward_approved"
    }
}
