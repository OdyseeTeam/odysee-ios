//
//  RemoteSubscription.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 07/12/2020.
//

import Foundation

public struct LbrySubscription: Decodable, Equatable, Hashable {
    
    public var claimId: String?
    public var channelName: String?
    public var notificationsDisabled: Bool?
    
    public init(
        claimId: String? = nil,
        channelName: String? = nil,
        notificationsDisabled: Bool? = nil
    ) {
        self.claimId = claimId
        self.channelName = channelName
        self.notificationsDisabled = notificationsDisabled
    }
    
    enum CodingKeys: String, CodingKey {
        case claimId = "claim_id"
        case channelName = "channel_name"
        case notificationsDisabled = "is_notifications_disabled"
    }
}

public extension LbrySubscription {
    
    static func fromClaim(claim: Claim, notificationsDisabled: Bool) -> LbrySubscription {
        var sub = LbrySubscription()
        sub.claimId = claim.claimId
        sub.channelName = claim.name
        sub.notificationsDisabled = notificationsDisabled
        return sub
    }
}
