//
//  LbryNotification.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 14/12/2020.
//

import Foundation

public struct LbryNotification: Decodable {
    public var id: Int64?
    public var notificationRule: String?
    public var isAppReadable: Bool?
    public var isRead: Bool?
    public var isSeen: Bool?
    public var isDeleted: Bool?
    public var createdAt: String?
    public var activeAt: String?
    public var notificationParameters: NotificationParameters?
    
    enum CodingKeys: String, CodingKey {
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
}

public extension LbryNotification {

    struct NotificationParameters: Decodable {
        
        public var dynamic: Dynamic?
        public var device: Device?

        enum CodingKeys: String, CodingKey {
            case dynamic
            case device
        }
    }

    struct Dynamic: Decodable {
        public var claimName: String?
        public var channelUrl: String?
        public var channelURI: String?
        public var claimTitle: String?
        public var hash: String?
        public var comment: String?
        public var parentId: String?
        public var commentAuthor: String?

        enum CodingKeys: String, CodingKey {
            case claimName = "claim_name"
            case channelUrl = "channel_url"
            case channelURI
            case claimTitle = "claim_title"
            case hash
            case comment
            case parentId = "parent_id"
            case commentAuthor = "comment_author"
        }
    }

    struct Device: Decodable {
        
        public var name: String?
        public var text: String?
        public var type: String?
        public var title: String?
        public var target: String?
        public var imageUrl: String?
        public var isDataOnly: Bool?

        enum CodingKeys: String, CodingKey {
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

public extension LbryNotification {
    
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
    
    var author: String? {
        return notificationParameters != nil && notificationParameters!.dynamic != nil ? notificationParameters!
            .dynamic!.commentAuthor : nil
    }
}
