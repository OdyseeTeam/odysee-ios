//
//  User.swift
//  Odysee
//
//  Created by Keith on 10/09/2026.
//

import Foundation

// FIXME: Logic of ?? false where fields aren't nil anymore
struct User: Decodable {
    var id: UInt64
//    var language: String
//    var givenName: String?
//    var familyName: String?
//    var createdAt: TimeInterval
//    var updatedAt: TimeInterval
//    var invitedByID: UInt64?
//    var invitedAt: TimeInterval?
//    var invitesRemaining: Int
//    var inviteRewardClaimed: Bool
    var isRewardApproved: Bool
//    var isEmailEnabled: Bool
//    var country: String?
//    var isOdyseeUser: Bool
//    var location: String?
    var youtubeChannels: [YoutubeChannel]
    var primaryEmail: String?
//    var passwordSet: Bool
    var latestClaimedEmail: String?
    var hasVerifiedEmail: Bool
//    var isIdentityVerified: Bool
//    var groups: [String]
//    var deviceTypes: [String]
//    var odyseeLiveEnabled: Bool
//    var odyseeLiveDisabled: Bool
//    var globalMod: Bool
//    var experimentalUI: Bool
//    var internalFeature: Bool
//    var odyseeMember: Bool
    var pendingDeletion: Bool

    enum CodingKeys: String, CodingKey {
        case id
        //    case language = "language"
        //    case givenName = "given_name"
        //    case familyName = "family_name"
        //    case createdAt = "created_at"
        //    case updatedAt = "updated_at"
        //    case invitedByID = "invited_by_i_d"
        //    case invitedAt = "invited_at"
        //    case invitesRemaining = "invites_remaining"
        //    case inviteRewardClaimed = "invite_reward_claimed"
        case isRewardApproved = "is_reward_approved"
        //    case isEmailEnabled = "is_email_enabled"
        //    case country = "country"
        //    case isOdyseeUser = "is_odysee_user"
        //    case location = "location"
        case youtubeChannels = "youtube_channels"
        case primaryEmail = "primary_email"
        //    case passwordSet = "password_set"
        case latestClaimedEmail = "latest_claimed_email"
        case hasVerifiedEmail = "has_verified_email"
        //    case isIdentityVerified = "is_identity_verified"
        //    case groups = "groups"
        //    case deviceTypes = "device_types"
        //    case odyseeLiveEnabled = "odysee_live_enabled"
        //    case odyseeLiveDisabled = "odysee_live_disabled"
        //    case globalMod = "global_mod"
        //    case experimentalUI = "experimental_u_i"
        //    case internalFeature = "internal_feature"
        //    case odyseeMember = "odysee_member"
        case pendingDeletion = "pending_deletion"
    }
}
