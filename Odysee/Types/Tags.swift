//
//  Tags.swift
//  Odysee
//
//  Created by Keith Toh on 12/05/2026.
//

import Foundation

/// Acts as an `Array<String>` but can decode from an array of JSON objects with key `name`\
/// Holds `Optional` as property wrapper properties can't be optional
@propertyWrapper
public struct Tags: Codable, Equatable {
    public var wrappedValue: [String]?

    private struct Tag: Codable {
        var name: String
    }

    init(_ tags: [String]?) {
        wrappedValue = tags
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let tags = try? container.decode([String].self) {
            wrappedValue = tags
        } else {
            let tags = try container.decode([Tag].self)
            wrappedValue = tags.map(\.name)
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(wrappedValue?.map(Tag.init))
    }
}

extension KeyedDecodingContainer {
    /// Handle decoding property wrapper with optional wrapped value
    /// <https://forums.swift.org/t/using-property-wrappers-with-codable/29804/12>
    func decode(_ type: Tags.Type, forKey key: Self.Key) throws -> Tags {
        try decodeIfPresent(type, forKey: key) ?? Tags(nil)
    }
}
