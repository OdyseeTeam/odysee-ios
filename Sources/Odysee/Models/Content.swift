//
//  Content.swift
//  
//
//  Created by Alsey Coleman Miller on 8/5/23.
//

import Foundation

/// Odysee Content Data
public struct Content: Equatable, Hashable, Codable {
    
    public let categories: [String: Channel]
    
    public let portals: Portals?
    
    public let featured: Featured?
    
    public let meme: Meme?
    
    public let discover: [String]?
    
    public let announcement: String?
}

public extension Content {
    
    /// Odysee Channel
    struct Channel: Equatable, Hashable, Codable {
        
        public let channelIds: [String]?
        public let name: String
        public let sortOrder: Int?
        public let icon: String
        public let label: String
        public let description: String?
        public let image: String? // could be empty string
        //public let channelLimit: UInt? Could be string or number
        public let daysOfContent: Int?
        public let duration: String?
        public let pageSize: Int?
        public let order: String?
        public let claimType: [ClaimType]?
    }
}

public extension Content {
    
    /// Odysee Meme
    struct Meme: Equatable, Hashable, Codable {
        
        public let text: String?
        
        public let url: URL?
    }
}

public extension Content {
    
    struct Featured: Equatable, Hashable, Codable {
        
        public let transitionTime: UInt
        
        public let items: [Item]
    }
}

public extension Content.Featured {
    
    struct Item: Equatable, Hashable, Codable {
        
        public let label: String
        
        public let image: URL
        
        public let url: URL
    }
}

public extension Content {
    
    struct Portals: Equatable, Hashable, Codable {
        
        public let tagline: String
        
        public let mainPortal: Portal
    }
}

public extension Content {
    
    struct Portal: Equatable, Hashable, Codable {
        
        public let name: String
        
        public let label: String
        
        public let description: String
        
        public let background: URL
        
        public let sortOrder: Int?
        
        public let css: [String: String]?
        
        public let portals: [Portal]?
        
        public let claimIds: Claims?
    }
}

public extension Content.Portal {
    
    struct Claims: Equatable, Hashable, Codable {
        
        public let videos: [String]
        
        public let creators: [String]
        
        public let documents: [String]
        
        public let images: [String]
    }
}
