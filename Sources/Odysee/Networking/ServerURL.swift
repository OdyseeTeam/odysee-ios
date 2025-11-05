//
//  ServerURL.swift
//  
//
//  Created by Alsey Coleman Miller on 8/5/23.
//

import Foundation

/// Odysee Server
public struct OdyseeServer: Codable, Equatable, Hashable, Sendable {
    
    internal let url: URL
    
    internal init(url: URL) {
        self.url = url
    }
}

public extension URL {
    
    init(server: OdyseeServer) {
        self = server.url
    }
}

// MARK: - RawRepresentable

extension OdyseeServer: RawRepresentable {
    
    public init?(rawValue: String) {
        guard let url = URL(string: rawValue) else {
            return nil
        }
        self.init(url: url)
    }
    
    public var rawValue: String {
        url.absoluteString
    }
}

// MARK: - CustomStringConvertible

extension OdyseeServer: CustomStringConvertible, CustomDebugStringConvertible {
    
    public var description: String {
        rawValue
    }
    
    public var debugDescription: String {
        rawValue
    }
}

// MARK: - Definitions

public extension OdyseeServer {
    
    static var production: OdyseeServer {
        return OdyseeServer(rawValue: "https://odysee.com")!
    }
}
