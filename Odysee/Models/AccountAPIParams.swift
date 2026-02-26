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

struct UserExistsParams: Encodable, AccountMethodParams {
    var email: String
}

struct UserSignInUpParams: Encodable, AccountMethodParams {
    var email: String
    var password: String
}

struct UserEmailResendTokenParams: Encodable, AccountMethodParams {
    var email: String
    let onlyIfExpired = true

    enum CodingKeys: String, CodingKey {
        case email
        case onlyIfExpired = "only_if_expired"
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

struct YtNewParams: Encodable, AccountMethodParams {
    let type = "sync"
    let immediateSync = true
    var channelLanguage: String
    var desiredLbryChannelName: String
    let returnUrl = YouTubeSyncScreen.Setup.returnUrl

    enum CodingKeys: String, CodingKey {
        case type
        case immediateSync = "immediate_sync"
        case channelLanguage = "channel_language"
        case desiredLbryChannelName = "desired_lbry_channel_name"
        case returnUrl = "return_url"
    }
}

struct YtTransferParams: Encodable, AccountMethodParams {
    var address: String
    var publicKey: String

    enum CodingKeys: String, CodingKey {
        case address
        case publicKey = "public_key"
    }
}
