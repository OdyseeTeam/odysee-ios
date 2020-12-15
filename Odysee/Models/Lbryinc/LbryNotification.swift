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
        return notificationParameters != nil && notificationParameters!.device != nil ? notificationParameters!.device!.title : nil
    }
    var text: String? {
        return notificationParameters != nil && notificationParameters!.device != nil ? notificationParameters!.device!.text : nil
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
        return notificationParameters != nil && notificationParameters!.dynamic != nil ? notificationParameters!.dynamic!.commentAuthor : nil
    }
    
    private enum CodingKeys: String, CodingKey {
        case id = "id", notificationRule = "notification_rule", isAppReadable = "is_app_readable", isRead = "is_read", isSeen = "is_seen", isDeleted = "is_deleted", createdAt = "created_at", activeAt = "active_at", notificationParameters = "notification_parameters"
    }
    
    struct NotificationParameters: Decodable {
        var dynamic: Dynamic?
        var device: Device?
        
        private enum CodingKeys: String, CodingKey {
            case dynamic = "dynamic", device = "device"
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
        var commentAuthor: String?
        
        private enum CodingKeys: String, CodingKey {
            case claimName = "claim_name", channelUrl = "channel_url", channelURI = "channelURI", claimTitle = "claim_title",
                 hash = "hash", comment = "comment", parentId = "parent_id", commentAuthor = "comment_author"
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
            case name = "name", text = "text", type = "type", title = "title", target = "target", imageUrl = "image_url", isDataOnly = "is_data_only"
        }
    }
}
