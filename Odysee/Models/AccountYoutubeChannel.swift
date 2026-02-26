//
//  AccountYoutubeChannel.swift
//  Odysee
//
//  Created by Keith Toh on 12/02/2026.
//

import Foundation

struct AccountYoutubeChannel: Decodable {
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

    private enum CodingKeys: String, CodingKey {
        case ytChannelId = "yt_channel_id"
        case ytChannelName = "yt_channel_name"
        case lbryChannelName = "lbry_channel_name"
        case channelClaimId = "channel_claim_id"
        case syncStatus = "sync_status"
        case statusToken = "status_token"
        case transferable
        case transferState = "transfer_state"
        case shouldSync = "should_sync"
        case vip
        case reviewed
        case totalSubs = "total_subs"
        case totalVideos = "total_videos"
        case publishToAddress = "publish_to_address"
        case publicKey = "public_key"
        case channelCertificate = "channel_certificate"
    }

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

extension AccountYoutubeChannel: Identifiable {
    var id: String {
        ytChannelId
    }
}
