//
//  LbryNotification.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 14/12/2020.
//

import Foundation

struct LbryNotification: Decodable {
    var id: Int64?
    var notificationRule: String?
    var isAppReadable: Bool?
    var isRead: Bool?
    var isSeen: Bool?
    var isDeleted: Bool?
    var createdAt: String?
    var activeAt: String?
    var notificationParameters: NotificationParameters?

    var title: String? {
        return notificationParameters != nil && notificationParameters!.device != nil ? notificationParameters!.device!
            .title : nil
    }

    var text: String? {
        return notificationParameters != nil && notificationParameters!.device != nil ? notificationParameters!.device!
            .text : nil
    }

    var targetUrl: String? {
        if notificationParameters != nil {
            if notificationParameters!.device != nil {
                return notificationParameters!.device!.target
            }

            if notificationParameters!.dynamic != nil {
                if notificationParameters!.dynamic!.channelURI != nil {
                    return notificationParameters!.dynamic!.channelURI
                }
                if notificationParameters!.dynamic!.channelUrl != nil {
                    return notificationParameters!.dynamic!.channelUrl
                }
            }
        }

        return nil
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case notificationRule = "notification_rule"
        case isAppReadable = "is_app_readable"
        case isRead = "is_read"
        case isSeen = "is_seen"
        case isDeleted = "is_deleted"
        case createdAt = "created_at"
        case activeAt = "active_at"
        case notificationParameters = "notification_parameters"
    }

    struct NotificationParameters: Decodable {
        var dynamic: Dynamic?
        var device: Device?

        private enum CodingKeys: String, CodingKey {
            case dynamic
            case device
        }
    }

    struct Dynamic: Decodable {
        var claimName: String?
        var channelUrl: String?
        var channelURI: String?
        var claimTitle: String?
        var hash: String?
        var comment: String?
        var parentId: String?
        var commentAuthorThumbnail: String?

        private enum CodingKeys: String, CodingKey {
            case claimName = "claim_name"
            case channelUrl = "channel_url"
            case channelURI
            case claimTitle = "claim_title"
            case hash
            case comment
            case parentId = "parent_id"
            case commentAuthorThumbnail = "comment_author_thumbnail"
        }
    }

    struct Device: Decodable {
        var name: String?
        var text: String?
        var type: String?
        var title: String?
        var target: String?
        var imageUrl: String?
        var isDataOnly: Bool?

        private enum CodingKeys: String, CodingKey {
            case name
            case text
            case type
            case title
            case target
            case imageUrl = "image_url"
            case isDataOnly = "is_data_only"
        }
    }
}
