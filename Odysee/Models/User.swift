//
//  User.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 10/11/2020.
//

import Foundation

struct User: Decodable {
    var createdAt: String?
    var familyName: String?
    var givenName: String?
    var groups: [String]?
    var hasVerifiedEmail: Bool?
    var id: Int64?
    var inviteRewardClaimed: Bool?
    var invitedAt: String?
    var invitedById: Int64?
    var invitesRemaining: Int?
    var isEmailEnabled: Bool?
    var isIdentityVerified: Bool?
    var isRewardApproved: Bool?
    var language: String?
    var manualApprovalUserId: Int64?
    var primaryEmail: String?
    var rewardStatusChangeTrigger: String?
    var youtubeChannels: [YoutubeChannel]?
    var deviceTypes: [String]?
    
    private enum CodingKeys: String, CodingKey {
        case createdAt = "created_at", familyName = "family_name", givenName = "given_name", groups, hasVerifiedEmail = "has_verified_email", id, inviteRewardClaimed = "invite_reward_claimed", invitedAt = "invited_at", invitedById = "invited_by_id", invitesRemaining = "invites_remaining", isEmailEnabled = "is_email_enabled", isIdentityVerified = "is_identity_verified", isRewardApproved = "is_reward_approved", language = "language", manualApprovalUserId = "manual_approval_user_id", primaryEmail = "primary_email",
             rewardStatusChangeTrigger = "reward_status_change_trigger", youtubeChannels = "youtube_channels", deviceTypes = "device_types"
    }
    
    struct YoutubeChannel: Decodable {
        var ytChannelName: String?
        var lbryChannelName: String?
        var channelClaimId: String?
        var syncStatus: String?
        var statusToken: String?
        var transferable: Bool?
        var transferState: String?
        var publishToAddress: [String]?
        var publicKey: String?
        
        private enum CodingKeys: String, CodingKey {
            case ytChannelName = "yt_channel_name", lbryChannelName = "lbry_channel_name", channelClaimId = "channel_claim_id", syncStatus = "sync_status", statusToken = "status_token", transferable = "transferable", transferState = "transfer_state", publishToAddress = "publish_to_address", publicKey = "public_key"
        }
    }
}
