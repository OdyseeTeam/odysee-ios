//
//  QueryItemsEncoder.swift
//  Odysee
//
//  Created by Keith Toh on 18/12/2025.
//

// https://stackoverflow.com/a/54612620

import Foundation

public class QueryItemsEncoder {
    public init() {}

    public func encode<T: Encodable>(_ value: T) throws -> [URLQueryItem] {
        let queryItemsEncoding = QueryItemsEncoding()
        try value.encode(to: queryItemsEncoding)
        return queryItemsEncoding.queryItems.queryItems
    }
}

private struct QueryItemsEncoding: Encoder {
    fileprivate final class QueryItems {
        private(set) var queryItems: [URLQueryItem] = []

        func encode(key codingKey: [CodingKey], value: String) {
            let name = codingKey.map(\.stringValue).joined(separator: ".")
            queryItems.append(URLQueryItem(name: name, value: value))
        }
    }

    fileprivate var queryItems: QueryItems

    init(to queryItems: QueryItems = QueryItems()) {
        self.queryItems = queryItems
    }

    var codingPath: [any CodingKey] = []

    var userInfo: [CodingUserInfoKey: Any] = [:]

    func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key: CodingKey {
        var container = QueryItemsKeyedEncoding<Key>(to: queryItems)
        container.codingPath = codingPath
        return KeyedEncodingContainer(container)
    }

    func unkeyedContainer() -> any UnkeyedEncodingContainer {
        var container = QueryItemsUnkeyedEncoding(to: queryItems)
        container.codingPath = codingPath
        return container
    }

    func singleValueContainer() -> any SingleValueEncodingContainer {
        var container = QueryItemsSingleValueEncoding(to: queryItems)
        container.codingPath = codingPath
        return container
    }
}

private struct QueryItemsKeyedEncoding<Key: CodingKey>: KeyedEncodingContainerProtocol {
    private let queryItems: QueryItemsEncoding.QueryItems

    init(to queryItems: QueryItemsEncoding.QueryItems) {
        self.queryItems = queryItems
    }

    var codingPath: [any CodingKey] = []

    mutating func encodeNil(forKey key: Key) throws {
        queryItems.encode(key: codingPath + [key], value: "nil")
    }

    mutating func encode(_ value: Bool, forKey key: Key) throws {
        queryItems.encode(key: codingPath + [key], value: value.description)
    }

    mutating func encode(_ value: String, forKey key: Key) throws {
        queryItems.encode(key: codingPath + [key], value: value)
    }

    mutating func encode(_ value: Double, forKey key: Key) throws {
        queryItems.encode(key: codingPath + [key], value: value.description)
    }

    mutating func encode(_ value: Float, forKey key: Key) throws {
        queryItems.encode(key: codingPath + [key], value: value.description)
    }

    mutating func encode(_ value: Int, forKey key: Key) throws {
        queryItems.encode(key: codingPath + [key], value: value.description)
    }

    mutating func encode(_ value: Int8, forKey key: Key) throws {
        queryItems.encode(key: codingPath + [key], value: value.description)
    }

    mutating func encode(_ value: Int16, forKey key: Key) throws {
        queryItems.encode(key: codingPath + [key], value: value.description)
    }

    mutating func encode(_ value: Int32, forKey key: Key) throws {
        queryItems.encode(key: codingPath + [key], value: value.description)
    }

    mutating func encode(_ value: Int64, forKey key: Key) throws {
        queryItems.encode(key: codingPath + [key], value: value.description)
    }

    mutating func encode(_ value: UInt, forKey key: Key) throws {
        queryItems.encode(key: codingPath + [key], value: value.description)
    }

    mutating func encode(_ value: UInt8, forKey key: Key) throws {
        queryItems.encode(key: codingPath + [key], value: value.description)
    }

    mutating func encode(_ value: UInt16, forKey key: Key) throws {
        queryItems.encode(key: codingPath + [key], value: value.description)
    }

    mutating func encode(_ value: UInt32, forKey key: Key) throws {
        queryItems.encode(key: codingPath + [key], value: value.description)
    }

    mutating func encode(_ value: UInt64, forKey key: Key) throws {
        queryItems.encode(key: codingPath + [key], value: value.description)
    }

    mutating func encode<T>(_ value: T, forKey key: Key) throws where T: Encodable {
        var encoding = QueryItemsEncoding(to: queryItems)
        encoding.codingPath = codingPath + [key]
        try value.encode(to: encoding)
    }

    mutating func nestedContainer<NestedKey>(
        keyedBy keyType: NestedKey.Type, forKey key: Key
    ) -> KeyedEncodingContainer<NestedKey> where NestedKey: CodingKey {
        var container = QueryItemsKeyedEncoding<NestedKey>(to: queryItems)
        container.codingPath = codingPath + [key]
        return KeyedEncodingContainer(container)
    }

    mutating func nestedUnkeyedContainer(forKey key: Key) -> any UnkeyedEncodingContainer {
        var container = QueryItemsUnkeyedEncoding(to: queryItems)
        container.codingPath = codingPath + [key]
        return container
    }

    mutating func superEncoder() -> any Encoder {
        // swift-format-ignore
        let superKey = Key(stringValue: "super")!
        return superEncoder(forKey: superKey)
    }

    mutating func superEncoder(forKey key: Key) -> any Encoder {
        var encoding = QueryItemsEncoding(to: queryItems)
        encoding.codingPath = codingPath + [key]
        return encoding
    }
}

fileprivate struct QueryItemsUnkeyedEncoding: UnkeyedEncodingContainer {
    private let queryItems: QueryItemsEncoding.QueryItems

    init(to queryItems: QueryItemsEncoding.QueryItems) {
        self.queryItems = queryItems
    }

    var codingPath: [any CodingKey] = []

    private(set) var count: Int = 0

    private mutating func nextIndexedKey() -> CodingKey {
        let nextCodingKey = IndexedCodingKey(intValue: count)!
        count += 1
        return nextCodingKey
    }

    private struct IndexedCodingKey: CodingKey {
        let intValue: Int?
        let stringValue: String

        init?(intValue: Int) {
            self.intValue = intValue
            self.stringValue = intValue.description
        }

        init?(stringValue: String) {
            return nil
        }
    }

    mutating func encodeNil() throws {
        queryItems.encode(key: codingPath + [nextIndexedKey()], value: "nil")
    }

    mutating func encode(_ value: Bool) throws {
        queryItems.encode(key: codingPath + [nextIndexedKey()], value: value.description)
    }

    mutating func encode(_ value: String) throws {
        queryItems.encode(key: codingPath + [nextIndexedKey()], value: value)
    }

    mutating func encode(_ value: Double) throws {
        queryItems.encode(key: codingPath + [nextIndexedKey()], value: value.description)
    }

    mutating func encode(_ value: Float) throws {
        queryItems.encode(key: codingPath + [nextIndexedKey()], value: value.description)
    }

    mutating func encode(_ value: Int) throws {
        queryItems.encode(key: codingPath + [nextIndexedKey()], value: value.description)
    }

    mutating func encode(_ value: Int8) throws {
        queryItems.encode(key: codingPath + [nextIndexedKey()], value: value.description)
    }

    mutating func encode(_ value: Int16) throws {
        queryItems.encode(key: codingPath + [nextIndexedKey()], value: value.description)
    }

    mutating func encode(_ value: Int32) throws {
        queryItems.encode(key: codingPath + [nextIndexedKey()], value: value.description)
    }

    mutating func encode(_ value: Int64) throws {
        queryItems.encode(key: codingPath + [nextIndexedKey()], value: value.description)
    }

    mutating func encode(_ value: UInt) throws {
        queryItems.encode(key: codingPath + [nextIndexedKey()], value: value.description)
    }

    mutating func encode(_ value: UInt8) throws {
        queryItems.encode(key: codingPath + [nextIndexedKey()], value: value.description)
    }

    mutating func encode(_ value: UInt16) throws {
        queryItems.encode(key: codingPath + [nextIndexedKey()], value: value.description)
    }

    mutating func encode(_ value: UInt32) throws {
        queryItems.encode(key: codingPath + [nextIndexedKey()], value: value.description)
    }

    mutating func encode(_ value: UInt64) throws {
        queryItems.encode(key: codingPath + [nextIndexedKey()], value: value.description)
    }

    mutating func encode<T>(_ value: T) throws where T : Encodable {
        var encoding = QueryItemsEncoding(to: queryItems)
        encoding.codingPath = codingPath + [nextIndexedKey()]
        try value.encode(to: encoding)
    }

    mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
        var container = QueryItemsKeyedEncoding<NestedKey>(to: queryItems)
        container.codingPath = codingPath + [nextIndexedKey()]
        return KeyedEncodingContainer(container)
    }

    mutating func nestedUnkeyedContainer() -> any UnkeyedEncodingContainer {
        var container = QueryItemsUnkeyedEncoding(to: queryItems)
        container.codingPath = codingPath + [nextIndexedKey()]
        return container
    }

    mutating func superEncoder() -> any Encoder {
        var encoding = QueryItemsEncoding(to: queryItems)
        encoding.codingPath.append(nextIndexedKey())
        return encoding
    }
}

fileprivate struct QueryItemsSingleValueEncoding: SingleValueEncodingContainer {
    private let queryItems: QueryItemsEncoding.QueryItems

    init(to queryItems: QueryItemsEncoding.QueryItems) {
        self.queryItems = queryItems
    }

    var codingPath: [CodingKey] = []

    mutating func encodeNil() throws {
        queryItems.encode(key: codingPath, value: "nil")
    }

    mutating func encode(_ value: Bool) throws {
        queryItems.encode(key: codingPath, value: value.description)
    }

    mutating func encode(_ value: String) throws {
        queryItems.encode(key: codingPath, value: value)
    }

    mutating func encode(_ value: Double) throws {
        queryItems.encode(key: codingPath, value: value.description)
    }

    mutating func encode(_ value: Float) throws {
        queryItems.encode(key: codingPath, value: value.description)
    }

    mutating func encode(_ value: Int) throws {
        queryItems.encode(key: codingPath, value: value.description)
    }

    mutating func encode(_ value: Int8) throws {
        queryItems.encode(key: codingPath, value: value.description)
    }

    mutating func encode(_ value: Int16) throws {
        queryItems.encode(key: codingPath, value: value.description)
    }

    mutating func encode(_ value: Int32) throws {
        queryItems.encode(key: codingPath, value: value.description)
    }

    mutating func encode(_ value: Int64) throws {
        queryItems.encode(key: codingPath, value: value.description)
    }

    mutating func encode(_ value: UInt) throws {
        queryItems.encode(key: codingPath, value: value.description)
    }

    mutating func encode(_ value: UInt8) throws {
        queryItems.encode(key: codingPath, value: value.description)
    }

    mutating func encode(_ value: UInt16) throws {
        queryItems.encode(key: codingPath, value: value.description)
    }

    mutating func encode(_ value: UInt32) throws {
        queryItems.encode(key: codingPath, value: value.description)
    }

    mutating func encode(_ value: UInt64) throws {
        queryItems.encode(key: codingPath, value: value.description)
    }

    mutating func encode<T: Encodable>(_ value: T) throws {
        var encoding = QueryItemsEncoding(to: queryItems)
        encoding.codingPath = codingPath
        try value.encode(to: encoding)
    }
}
