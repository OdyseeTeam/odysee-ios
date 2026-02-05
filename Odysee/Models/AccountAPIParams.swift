//
//  AccountAPIParams.swift
//  Odysee
//
//  Created by Keith Toh on 24/12/2025.
//

import Foundation

struct UserNewParams: Encodable, AccountMethodParams {
    let language = "en"
    var appId: String

    enum CodingKeys: String, CodingKey {
        case language
        case appId = "app_id"
    }
}

struct SyncGetParams: Encodable, AccountMethodParams {
    var hash: String
}

struct SyncSetParams: Encodable, AccountMethodParams {
    var oldHash: String
    var newHash: String
    var data: String

    enum CodingKeys: String, CodingKey {
        case oldHash = "old_hash"
        case newHash = "new_hash"
        case data
    }
}

struct SubscriptionNewParams: Encodable, AccountMethodParams {
    var claimId: String
    var channelName: String
    var notificationsDisabled: Bool

    enum CodingKeys: String, CodingKey {
        case claimId = "claim_id"
        case channelName = "channel_name"
        case notificationsDisabled = "notifications_disabled"
    }
}
