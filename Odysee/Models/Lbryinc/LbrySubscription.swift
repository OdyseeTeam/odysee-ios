//
//  LbrySubscription.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 07/12/2020.
//

import Foundation

struct LbrySubscription: Decodable {
    var claimId: String?
    var channelName: String?
    var notificationsDisabled: Bool?

    private enum CodingKeys: String, CodingKey {
        case claimId = "claim_id"
        case channelName = "channel_name"
        case notificationsDisabled = "is_notifications_disabled"
    }

    static func fromClaim(claim: Claim, notificationsDisabled: Bool) -> LbrySubscription {
        var sub = LbrySubscription()
        sub.claimId = claim.claimId
        sub.channelName = claim.name
        sub.notificationsDisabled = notificationsDisabled

        return sub
    }

    static func fromLocalSubscription(subscription: Subscription) -> LbrySubscription {
        var sub = LbrySubscription()
        if let subUrl = subscription.url,
           let url = LbryUri.tryParse(url: subUrl, requireProto: false)
        {
            sub.claimId = url.channelClaimId
            sub.channelName = url.channelName
        }
        sub.notificationsDisabled = subscription.isNotificationsDisabled

        return sub
    }
}
