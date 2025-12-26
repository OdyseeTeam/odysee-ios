//
//  Following.swift
//  Odysee
//
//  Created by Keith Toh on 26/12/2025.
//

import Foundation

/// Only channelName, channelClaimId; requireProto = true
typealias Follow = LbryUri

typealias NotificationsDisabled = Bool

typealias Following = [Follow: NotificationsDisabled]
