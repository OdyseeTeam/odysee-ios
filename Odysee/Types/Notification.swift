//
//  Notification.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 14/12/2020.
//

import Foundation
import ValueCodable

struct Notification: Decodable, Identifiable {
    var id: UInt64
    var notificationRule: NotificationRule
    /// Whether notification has been "opened"
    var isRead: Bool
    /// Whether notification has been viewed in NotificationsScreen\
    /// Unseen count is used for Notifications unseen badge
    var isSeen: Bool
    var activeAt: Date
    var notificationParameters: NotificationParameters?

    var title: String? {
        notificationParameters?.device.title
    }

    var text: String? {
        notificationParameters?.device.text
    }

    var targetUrl: String? {
        notificationParameters?.device.target
    }

    var commentInfo: (String?, Bool) {
        switch notificationParameters?.dynamic {
        case let .comment(comment):
            (comment.hash, !comment.parentId.isEmpty)
        case let .reply(reply):
            (reply.hash, !reply.parentId.isEmpty)
        default:
            (nil, false)
        }
    }

    enum NotificationRule: String, Decodable {
        case creatorSubscriber = "creator_subscriber"

        case comment
        case creatorComment = "creator_comment"
        case commentReply = "comment-reply"

        case newContent = "new_content"

        case newLivestream = "new_livestream"

        case newMember = "new_member"

        case weeklyWatchReminder = "weekly_watch_reminder"
        case dailyWatchAvailable = "daily_watch_available"
        case dailyWatchRemind = "daily_watch_remind"
        case missedOut = "missed_out"
        case rewardsApprovalPrompt = "rewards_approval_prompt"

        case fiatTip = "fiat_tip"

        case other
    }

    struct NotificationParameters: Decodable {
        var device: Device
        var dynamic: Dynamic

        enum CodingKeys: CodingKey {
            case dynamic
            case device
        }

        init(device: Device, dynamic: Dynamic) {
            self.device = device
            self.dynamic = dynamic
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            device = try container.decode(Device.self, forKey: .device)

            dynamic = switch device.type {
            case "comment":
                try .comment(container.decode(Dynamic.Comment.self, forKey: .dynamic))
            case "livestream":
                try .livestream(container.decode(Dynamic.ClaimInfo.self, forKey: .dynamic))
            case "reply":
                try .reply(container.decode(Dynamic.Reply.self, forKey: .dynamic))
            case "reward":
                .reward(())
            case "rewards":
                try .rewards(container.decode(Dynamic.Rewards.self, forKey: .dynamic))
            case "subscription":
                try .subscription(container.decodeIfPresent(Dynamic.ClaimInfo.self, forKey: .dynamic))
            default:
                try .unknown(container.decode(Value.self, forKey: .dynamic))
            }
        }

        struct Device: Decodable {
            var name: String
            var title: String
            var text: String
            var type: String
            var target: String
        }

        enum Dynamic {
            case comment(Comment)
            case livestream(ClaimInfo)
            case reply(Reply)
            case reward(Void)
            case rewards(Rewards)
            case subscription(ClaimInfo?)

            case unknown(Value)

            // MARK: Dynamic map access helpers

            var commentAuthorThumbnail: String? {
                if case let .comment(comment) = self {
                    comment.commentAuthorThumbnail
                } else if case let .reply(reply) = self {
                    reply.commentAuthorThumbnail
                } else {
                    nil
                }
            }

            // MARK: Dynamic map definitions

            struct Comment: Decodable {
                var hash: String
                var parentId: String
                var commentAuthor: String
                var claimTitle: String
                var comment: String
                var amount: String
                var currency: String?
                var commentAuthorThumbnail: String
            }

            struct ClaimInfo: Decodable {
                var claimTitle: String
                var channelUrl: String
                var channelThumbnail: String
                var claimThumbnail: String
                var claimName: String
            }

            struct Reply: Decodable {
                var hash: String
                var parentId: String
                var replyAuthor: String
                var claimTitle: String
                var parentComment: String
                var comment: String
                var amount: String
                var commentAuthorThumbnail: String
            }

            struct Rewards: Decodable {
                var channelURI: String
            }
        }
    }
}
