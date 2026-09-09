//
//  Notification.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 14/12/2020.
//

import Foundation
import ValueCodable

struct Notification: Decodable {
    var id: Int64
    var notificationRule: String
    var isAppReadable: Bool
    var isRead: Bool
    var isSeen: Bool
    var createdAt: Date
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

    private enum CodingKeys: String, CodingKey {
        case id
        case notificationRule = "notification_rule"
        case isAppReadable = "is_app_readable"
        case isRead = "is_read"
        case isSeen = "is_seen"
        case createdAt = "created_at"
        case notificationParameters = "notification_parameters"
    }

    struct NotificationParameters: Decodable {
        var device: Device
        var dynamic: Dynamic

        enum CodingKeys: CodingKey {
            case dynamic
            case device
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            device = try container.decode(Device.self, forKey: .device)

            dynamic = switch device.type {
            case "comment":
                try .comment(container.decode(Dynamic.Comment.self, forKey: .dynamic))
            case "livestream":
                try .livestream(container.decode(Dynamic.Claim.self, forKey: .dynamic))
            case "reply":
                try .reply(container.decode(Dynamic.Reply.self, forKey: .dynamic))
            case "rewards":
                try .rewards(container.decode(Dynamic.Reward.self, forKey: .dynamic))
            case "subscription":
                try .subscription(container.decode(Dynamic.Claim.self, forKey: .dynamic))
            default:
                try .unknown(container.decode(Value.self, forKey: .dynamic)) // FIXME: Test
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
            case livestream(Claim)
            case reply(Reply)
            case rewards(Reward)
            case subscription(Claim)

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

                enum CodingKeys: String, CodingKey {
                    case hash
                    case parentId = "parent_id"
                    case commentAuthor = "comment_author"
                    case claimTitle = "claim_title"
                    case comment
                    case amount
                    case currency
                    case commentAuthorThumbnail = "comment_author_thumbnail"
                }
            }

            struct Claim: Decodable {
                var claimTitle: String
                var channelUrl: String
                var channelThumbnail: String
                var claimThumbnail: String
                var claimName: String

                enum CodingKeys: String, CodingKey {
                    case claimTitle = "claim_title"
                    case channelUrl = "channel_url"
                    case channelThumbnail = "channel_thumbnail"
                    case claimThumbnail = "claim_thumbnail"
                    case claimName = "claim_name"
                }
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

                enum CodingKeys: String, CodingKey {
                    case hash
                    case parentId = "parent_id"
                    case replyAuthor = "reply_author"
                    case claimTitle = "claim_title"
                    case parentComment = "parent_comment"
                    case comment
                    case amount
                    case commentAuthorThumbnail = "comment_author_thumbnail"
                }
            }

            struct Reward: Decodable {
                var channelURI: String
            }
        }
    }
}
