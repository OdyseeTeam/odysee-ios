//
//  SharedPreference+Following.swift
//  Odysee
//
//  Created by Keith Toh on 09/04/2026.
//

import Foundation

extension SharedPreference {
    typealias Follow = LbryUri

    typealias NotificationsDisabled = Bool
    typealias Follows = [Follow: NotificationsDisabled]

    @propertyWrapper
    struct Following: Codable {
        var wrappedValue: Follows

        init(_ follows: Follows) {
            wrappedValue = follows
        }

        private struct FollowingItem: Codable {
            var notificationsDisabled: Bool
            var uri: LbryUri

            init(notificationsDisabled: Bool, uri: LbryUri) {
                self.notificationsDisabled = notificationsDisabled
                self.uri = uri
            }

            init(from decoder: any Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                notificationsDisabled = try container.decodeIfPresent(Bool.self, forKey: .notificationsDisabled) ?? true
                uri = try container.decode(LbryUri.self, forKey: .uri)
            }
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.singleValueContainer()

            let followingItems = try container.decode([FollowingItem].self)

            wrappedValue = try Dictionary(
                followingItems.compactMap {
                    guard let follow = try Follow(channelName: $0.uri.channelName, claimId: $0.uri.claimId) else {
                        return nil
                    }

                    return (follow, $0.notificationsDisabled)
                },
                uniquingKeysWith: { _, last in last }
            )
        }

        func encode(to encoder: any Encoder) throws {
            var container = encoder.singleValueContainer()

            let followingItems = wrappedValue.map {
                FollowingItem(
                    notificationsDisabled: $0.value,
                    uri: $0.key
                )
            }

            try container.encode(followingItems)
        }
    }
}

extension SharedPreference.Follow {
    init?(channelName: String?, claimId: String?) throws {
        guard var channelName, let claimId else {
            return nil
        }

        channelName = channelName.starts(with: "@") ? channelName : "@\(channelName)"
        self = try LbryUri.parse(url: "lbry://\(channelName):\(claimId)", requireProto: true)
    }

    init?(channelClaim claim: Claim) {
        guard let channelName = claim.name,
              channelName.starts(with: "@"),
              let claimId = claim.claimId,
              let follow = try? Self(channelName: channelName, claimId: claimId)
        else {
            return nil
        }

        self = follow
    }
}

// MARK: - Mutators and Predicates

extension SharedPreference {
    mutating func addOrSetFollowing(claim: Claim, notificationsDisabled: NotificationsDisabled) {
        addOrSetFollowingAll(values: [claim: notificationsDisabled])
    }

    mutating func addOrSetFollowingAll(values: [Claim: NotificationsDisabled]) {
        var newFollowing = following

        for (claim, notificationsDisabled) in values {
            guard let follow = Follow(channelClaim: claim) else {
                return
            }

            newFollowing[follow] = notificationsDisabled
        }

        following = newFollowing
    }

    mutating func removeFollowing(claim: Claim) {
        guard let follow = Follow(channelClaim: claim) else {
            return
        }

        following.removeValue(forKey: follow)
    }

    mutating func updateNotificationsDisabledAll_and_removeFollowingAll(
        toUpdate: [Claim: NotificationsDisabled],
        toRemove: [Claim]
    ) {
        var newFollowing = following

        for (claim, notificationsDisabled) in toUpdate {
            guard let follow = Follow(channelClaim: claim) else {
                return
            }

            newFollowing[follow] = notificationsDisabled
        }

        for claim in toRemove {
            guard let follow = Follow(channelClaim: claim) else {
                return
            }

            newFollowing.removeValue(forKey: follow)
        }

        following = newFollowing
    }

    func isFollowing(claim: Claim) -> Bool {
        guard let follow = Follow(channelClaim: claim) else {
            return false
        }

        return following[follow] != nil
    }

    /// Defaults to true (disabled) if requested following doesn't exist
    func isNotificationsDisabled(claim: Claim) -> NotificationsDisabled {
        guard let follow = Follow(channelClaim: claim) else {
            return true
        }

        return following[follow] ?? true
    }
}
