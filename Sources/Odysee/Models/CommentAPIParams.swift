//
//  CommentAPIParams.swift
//  Odysee
//
//  Created by Keith Toh on 11/07/2022.
//

import Foundation

public struct CommentListParams: Encodable, Hashable {
    public var claimId: String
    public var channelId: String?
    public var channelName: String?
    public var parentId: String?
    public var page: Int?
    public var pageSize: Int?
    public var skipValidation: Bool?
    public var topLevel: Bool? = true
    
    public init(claimId: String, channelId: String? = nil, channelName: String? = nil, parentId: String? = nil, page: Int? = nil, pageSize: Int? = nil, skipValidation: Bool? = nil, topLevel: Bool? = nil) {
        self.claimId = claimId
        self.channelId = channelId
        self.channelName = channelName
        self.parentId = parentId
        self.page = page
        self.pageSize = pageSize
        self.skipValidation = skipValidation
        self.topLevel = topLevel
    }
}

public struct CommentCreateParams: Encodable, Hashable {
    public var claimId: String
    public var channelId: String
    public var signature: String
    public var signingTs: String
    public var comment: String
    public var parentId: String?
    
    public init(claimId: String, channelId: String, signature: String, signingTs: String, comment: String, parentId: String? = nil) {
        self.claimId = claimId
        self.channelId = channelId
        self.signature = signature
        self.signingTs = signingTs
        self.comment = comment
        self.parentId = parentId
    }
}

public struct CommentReactParams: Encodable, Hashable {
    public var commentIds: String
    public var signature: String
    public var signingTs: String
    public var remove: Bool?
    public var clearTypes: String?
    public var type: String
    public var channelId: String
    public var channelName: String
    
    public init(commentIds: String, signature: String, signingTs: String, remove: Bool? = nil, clearTypes: String? = nil, type: String, channelId: String, channelName: String) {
        self.commentIds = commentIds
        self.signature = signature
        self.signingTs = signingTs
        self.remove = remove
        self.clearTypes = clearTypes
        self.type = type
        self.channelId = channelId
        self.channelName = channelName
    }
}

public struct CommentReactListParams: Encodable, Hashable {
    public var commentIds: String
    public var channelName: String?
    public var channelId: String?
    public var signature: String?
    public var signingTs: String?
    
    public init(commentIds: String, channelName: String? = nil, channelId: String? = nil, signature: String? = nil, signingTs: String? = nil) {
        self.commentIds = commentIds
        self.channelName = channelName
        self.channelId = channelId
        self.signature = signature
        self.signingTs = signingTs
    }
}
