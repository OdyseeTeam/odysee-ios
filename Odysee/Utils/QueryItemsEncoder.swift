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

        func encode(key codingKey: CodingKey, value: String?) {
            let name = codingKey.stringValue
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
        fatalError("Only flat primitives are supported")
    }

    func singleValueContainer() -> any SingleValueEncodingContainer {
        fatalError("Only flat primitives are supported")
    }
}

private struct QueryItemsKeyedEncoding<Key: CodingKey>: KeyedEncodingContainerProtocol {
    private let queryItems: QueryItemsEncoding.QueryItems

    init(to queryItems: QueryItemsEncoding.QueryItems) {
        self.queryItems = queryItems
    }

    var codingPath: [any CodingKey] = []

    mutating func encodeNil(forKey key: Key) throws {
        fatalError("Nil shouldn't be encoded")
    }

    mutating func encode(_ value: Bool, forKey key: Key) throws {
        queryItems.encode(key: key, value: value.description)
    }

    mutating func encode(_ value: String, forKey key: Key) throws {
        queryItems.encode(key: key, value: value)
    }

    mutating func encode(_ value: Double, forKey key: Key) throws {
        queryItems.encode(key: key, value: value.description)
    }

    mutating func encode(_ value: Float, forKey key: Key) throws {
        queryItems.encode(key: key, value: value.description)
    }

    mutating func encode(_ value: Int, forKey key: Key) throws {
        queryItems.encode(key: key, value: value.description)
    }

    mutating func encode(_ value: Int8, forKey key: Key) throws {
        queryItems.encode(key: key, value: value.description)
    }

    mutating func encode(_ value: Int16, forKey key: Key) throws {
        queryItems.encode(key: key, value: value.description)
    }

    mutating func encode(_ value: Int32, forKey key: Key) throws {
        queryItems.encode(key: key, value: value.description)
    }

    mutating func encode(_ value: Int64, forKey key: Key) throws {
        queryItems.encode(key: key, value: value.description)
    }

    mutating func encode(_ value: UInt, forKey key: Key) throws {
        queryItems.encode(key: key, value: value.description)
    }

    mutating func encode(_ value: UInt8, forKey key: Key) throws {
        queryItems.encode(key: key, value: value.description)
    }

    mutating func encode(_ value: UInt16, forKey key: Key) throws {
        queryItems.encode(key: key, value: value.description)
    }

    mutating func encode(_ value: UInt32, forKey key: Key) throws {
        queryItems.encode(key: key, value: value.description)
    }

    mutating func encode(_ value: UInt64, forKey key: Key) throws {
        queryItems.encode(key: key, value: value.description)
    }

    mutating func encode<T>(_ value: T, forKey key: Key) throws where T: Encodable {
        fatalError("Only flat primitives are supported")
    }

    mutating func nestedContainer<NestedKey>(
        keyedBy keyType: NestedKey.Type, forKey key: Key
    ) -> KeyedEncodingContainer<NestedKey> where NestedKey: CodingKey {
        fatalError("Only flat primitives are supported")
    }

    mutating func nestedUnkeyedContainer(forKey key: Key) -> any UnkeyedEncodingContainer {
        fatalError("Only flat primitives are supported")
    }

    mutating func superEncoder() -> any Encoder {
        fatalError("Only flat primitives are supported")
    }

    mutating func superEncoder(forKey key: Key) -> any Encoder {
        fatalError("Only flat primitives are supported")
    }
}
