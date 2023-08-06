//
//  Mock.swift
//  
//
//  Created by Alsey Coleman Miller on 8/5/23.
//

import Foundation

#if DEBUG

public struct OdyseeMockJSONData: RawRepresentable, Equatable, Hashable {
    
    public let rawValue: String
    
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

public extension OdyseeMockJSONData {
    
    var data: Data {
        Data(rawValue.utf8)
    }
    
    func decode<T>(_ type: T.Type, decoder: JSONDecoder = .odysee) throws -> T where T: Decodable {
        try decoder.decode(type, from: Data(rawValue.utf8))
    }
}

// MARK: - ExpressibleByStringLiteral

extension OdyseeMockJSONData: ExpressibleByStringLiteral {
    
    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }
}

// MARK: - CustomStringConvertible

extension OdyseeMockJSONData: CustomStringConvertible, CustomDebugStringConvertible {
    
    public var description: String {
        rawValue
    }
    
    public var debugDescription: String {
        rawValue
    }
}

#endif
