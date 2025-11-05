//
//  LbrySubscription.swift
//  OdyseeApp
//
//  Created by Alsey Coleman Miller on 8/5/23.
//

import Foundation
import CoreData
import Odysee

extension LbrySubscription {
    
    static func fromLocalSubscription(subscription: OdyseeApp.Subscription) -> LbrySubscription {
        var sub = LbrySubscription()
        let url = LbryUri.tryParse(url: subscription.url!, requireProto: false)
        if url != nil {
            sub.claimId = url!.channelClaimId
            sub.channelName = url!.channelName
        }
        sub.notificationsDisabled = subscription.isNotificationsDisabled

        return sub
    }
}
