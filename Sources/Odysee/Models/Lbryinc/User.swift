//
//  User.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 10/11/2020.
//

import Foundation

public struct User: Decodable {
    
    public var createdAt: String?
    public var familyName: String?
    public var givenName: String?
    public var groups: [String]?
    public var hasVerifiedEmail: Bool?
    public var id: Int64?
    public var inviteRewardClaimed: Bool?
    public var invitedAt: String?
    public var invitedById: Int64?
    public var invitesRemaining: Int?
    public var isEmailEnabled: Bool?
    public var isIdentityVerified: Bool?
    public var isRewardApproved: Bool?
    public var language: String?
    public var manualApprovalUserId: Int64?
    public var primaryEmail: String?
    public var rewardStatusChangeTrigger: String?
    public var youtubeChannels: [YoutubeChannel]?
    public var deviceTypes: [String]?
    public var pendingDeletion: Bool?

    enum CodingKeys: String, CodingKey {
        case createdAt = "created_at"
        case familyName = "family_name"
        case givenName = "given_name"
        case groups
        case hasVerifiedEmail = "has_verified_email"
        case id
        case inviteRewardClaimed = "invite_reward_claimed"
        case invitedAt = "invited_at"
        case invitedById = "invited_by_id"
        case invitesRemaining = "invites_remaining"
        case isEmailEnabled = "is_email_enabled"
        case isIdentityVerified = "is_identity_verified"
        case isRewardApproved = "is_reward_approved"
        case language
        case manualApprovalUserId = "manual_approval_user_id"
        case primaryEmail = "primary_email"
        case rewardStatusChangeTrigger = "reward_status_change_trigger"
        case youtubeChannels = "youtube_channels"
        case deviceTypes = "device_types"
    }
}

public extension User {
    
    struct YoutubeChannel: Decodable {
        
        public var ytChannelName: String?
        public var lbryChannelName: String?
        public var channelClaimId: String?
        public var syncStatus: String?
        public var statusToken: String?
        public var transferable: Bool?
        public var transferState: String?
        public var publishToAddress: [String]?
        public var publicKey: String?

        enum CodingKeys: String, CodingKey {
            case ytChannelName = "yt_channel_name"
            case lbryChannelName = "lbry_channel_name"
            case channelClaimId = "channel_claim_id"
            case syncStatus = "sync_status"
            case statusToken = "status_token"
            case transferable
            case transferState = "transfer_state"
            case publishToAddress = "publish_to_address"
            case publicKey = "public_key"
        }
    }
}
