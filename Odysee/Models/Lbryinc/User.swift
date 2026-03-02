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
    var youtubeChannels: [AccountYoutubeChannel]?
    var deviceTypes: [String]?
    var pendingDeletion: Bool?

    private enum CodingKeys: String, CodingKey {
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
