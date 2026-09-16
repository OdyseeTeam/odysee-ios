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
}
