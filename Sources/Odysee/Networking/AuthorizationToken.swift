//
//  AuthorizationToken.swift
//  
//
//  Created by Alsey Coleman Miller on 8/5/23.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Odysee Authorization Token
public struct AuthorizationToken: Equatable, Hashable, RawRepresentable, Codable {
    
    public let rawValue: String
    
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

// MARK: - CustomStringConvertible

extension AuthorizationToken: CustomStringConvertible {
    
    public var description: String {
        rawValue
    }
}

// MARK: - ExpressibleByStringLiteral

extension AuthorizationToken: ExpressibleByStringLiteral {
    
    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }
}

// MARK: - HTTP Header

public extension URLRequest {
    
    mutating func setAuthorization(_ token: AuthorizationToken) {
        self.setValue(token.rawValue, forHTTPHeaderField: "Authorization")
    }
}
