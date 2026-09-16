//
//  YoutubeChannel.swift
//  Odysee
//
//  Created by Keith Toh on 12/02/2026.
//

import Foundation

struct YoutubeChannel: Decodable {
    var ytChannelId: String
    var ytChannelName: String
    var lbryChannelName: String
    var channelClaimId: String
    var syncStatus: SyncStatus
    var statusToken: String
    var transferable: Bool
    var transferState: TransferState
    var shouldSync: Bool
    var vip: Bool
    var reviewed: Bool
    var totalSubs: UInt
    var totalVideos: UInt
    var publishToAddress: [String]?
    var publicKey: String
    var channelCertificate: String?

    /// https://github.com/OdyseeTeam/ytsync/blob/f0a03d5bd7ed6cde87945482bbe676f6ca0ba1fe/shared/shared.go#L191-L205
    enum SyncStatus: String, Decodable {
        /// waiting for permission to sync
        case pending
        /// permission granted but missing email
        case pendingEmail = "pendingemail"
        /// in sync queue. will be synced soon
        case queued
        /// in sync queue. will be synced soon
        case pendingUpgrade = "pendingupgrade"
        /// syncing now
        case syncing
        /// done
        case synced
        /// in sync queue. lbryum database will be pruned
        case wipeDb = "pendingdbwipe"
        case failed
        /// no more changes allowed
        case finalized
        case abandoned
        /// one or more videos are age restricted and should be reprocessed with special keys
        case ageRestricted = "agerestricted"
    }

    enum TransferState: String, Decodable {
        case notTransferred = "not_transferred"
        case pendingTransfer = "pending_transfer"
        case completedTransfer = "completed_transfer"
        case legacyTransfer = "legacy_transfer"
    }
}

extension YoutubeChannel: Identifiable {
    var id: String {
        ytChannelId
    }
}
