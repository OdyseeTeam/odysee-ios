//
//  Reward.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 17/12/2020.
//

import Foundation

struct Reward: Decodable {
    static let typeCustom = "custom"
    static let typeFirstPublish = "first_publish"
    static let typeFirstChannel = "new_channel"
    static let typeNewMobile = "new_mobile"

    var id: Int64?
    var rewardType: String?
    var rewardAmount: Decimal?
    var transactionId: String?
    var createdAt: String?
    var updatedAt: String?
    var rewardTitle: String?
    var rewardDescription: String?
    var rewardNotification: String?
    var rewardRange: String?
    var rewardCode: String?

    var displayAmount: String {
        if shouldDisplayRange, let rewardRange {
            return String(rewardRange.split(separator: "-")[1])
        }
        if let rewardAmount, rewardAmount > 0,
           let formatted = Helper.currencyFormatter.string(for: rewardAmount)
        {
            return formatted
        }

        return "?"
    }

    var shouldDisplayRange: Bool {
        return !claimed && !rewardRange.isBlank && rewardRange?.firstIndex(of: "-") != nil
    }

    var claimed: Bool {
        return !transactionId.isBlank
    }

    private enum CodingKeys: String, CodingKey {
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
