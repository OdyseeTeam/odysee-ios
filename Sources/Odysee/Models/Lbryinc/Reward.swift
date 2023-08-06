//
//  Reward.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 17/12/2020.
//

import Foundation

public struct Reward: Decodable, Hashable {

    public var id: Int64?
    public var rewardType: RewardType?
    public var rewardAmount: Decimal?
    public var transactionId: String?
    public var createdAt: String?
    public var updatedAt: String?
    public var rewardTitle: String?
    public var rewardDescription: String?
    public var rewardNotification: String?
    public var rewardRange: String?
    public var rewardCode: String?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case rewardType = "reward_type"
        case rewardAmount = "reward_amount"
        case transactionId = "transaction_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case rewardTitle = "reward_title"
        case rewardDescription = "reward_description"
        case rewardNotification = "reward_notification"
        case rewardRange = "reward_range"
    }
}

public struct RewardType: RawRepresentable, Equatable, Hashable, Codable {
    
    public let rawValue: String
    
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

extension RewardType: CustomStringConvertible {
    
    public var description: String {
        rawValue
    }
}

extension RewardType: ExpressibleByStringLiteral {
    
    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }
}

public extension RewardType {
    
    static var custom: RewardType { "custom" }
    static var firstPublish: RewardType { "first_publish" }
    static var firstChannel: RewardType { "new_channel" }
    static var newMobile: RewardType { "new_mobile" }
}
