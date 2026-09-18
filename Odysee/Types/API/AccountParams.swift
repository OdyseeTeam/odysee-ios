//
//  AccountParams.swift
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
        case claimIds
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

struct NotificationListParams: Encodable, AccountMethodParams {
    let isAppReadable = true
}

struct NotificationEditParams: Encodable, AccountMethodParams {
    var notificationIds: [Notification.ID]
    var isRead: Bool?
    var isSeen: Bool?

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(
            notificationIds.map(String.init).joined(separator: ","),
            forKey: .notificationIds
        )
        try container.encodeIfPresent(isRead, forKey: .isRead)
        try container.encodeIfPresent(isSeen, forKey: .isSeen)
    }

    enum CodingKeys: String, CodingKey {
        case notificationIds
        case isRead
        case isSeen
    }
}

struct NotificationDeleteParams: Encodable, AccountMethodParams {
    var notificationIds: [Notification.ID]

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(
            notificationIds.map(String.init).joined(separator: ","),
            forKey: .notificationIds
        )
    }

    enum CodingKeys: String, CodingKey {
        case notificationIds
    }
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

struct ListAppleBlockedClaimIdsParams: Encodable, AccountMethodParams {
    let platform = "ios"
    let withClaimId = true
}

struct FileListClaimIdsParams: Encodable, AccountMethodParams {
    let withClaimId = true
}
