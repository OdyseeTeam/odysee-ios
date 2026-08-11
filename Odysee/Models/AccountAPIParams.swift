//
//  AccountAPIParams.swift
//  Odysee
//
//  Created by Keith Toh on 24/12/2025.
//

import Foundation

struct FileLastPositionsParams: Encodable, AccountMethodParams {
    var claimIds: [String]

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(claimIds.joined(separator: ","), forKey: .claimIds)
    }

    enum CodingKeys: String, CodingKey {
        case claimIds = "claim_ids"
    }
}

struct UserNewParams: Encodable, AccountMethodParams {
    let language = "en"
    var appId: String
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
}

struct InstallNewParams: Encodable, AccountMethodParams {
    var appVersion: String?
    var appId: String
    var firebaseToken: String?

    let operatingSystem = "ios"
    let platform = "darwin"
    let domain = "odysee.com"
}

struct SyncGetParams: Encodable, AccountMethodParams {
    var hash: String
}

struct SyncSetParams: Encodable, AccountMethodParams {
    var oldHash: String
    var newHash: String
    var data: String
}

struct SubscriptionNewParams: Encodable, AccountMethodParams {
    var claimId: String
    var channelName: String
    var notificationsDisabled: Bool
}

struct SubscriptionDeleteParams: Encodable, AccountMethodParams {
    var claimId: String
}

struct ViewHistoryParams: Encodable, AccountMethodParams {
    var page: Int?
    var pageSize: Int?
}

struct ViewHistoryDeleteParams: Encodable, AccountMethodParams {
    var claimId: String
}

struct YtNewParams: Encodable, AccountMethodParams {
    let type = "sync"
    let immediateSync = true
    var channelLanguage: String
    var desiredLbryChannelName: String
    let returnUrl = YouTubeSyncScreen.Setup.returnUrl
}

struct YtTransferParams: Encodable, AccountMethodParams {
    var address: String
    var publicKey: String
}
