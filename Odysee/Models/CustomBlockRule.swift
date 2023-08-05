//
//  CustomBlockRule.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 15/03/2022.
//

import Foundation

public enum CustomBlockContentType: String, Codable {
    case livestreams
    case videos
}

public enum CustomBlockScope: String, Codable {
    case continent
    case country
    case special
}

public struct CustomBlockRule: Identifiable, Hashable {
    
    public var type: CustomBlockContentType?
    public var scope: CustomBlockScope?
    public var reason: String?
    public var trigger: String?
    public var id: String?
    public var message: String?
    
    
}
