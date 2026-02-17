//
//  QueryItemsCoder.swift
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

public class QueryItemsDecoder {
    public init() {}

    public func decode<T: Decodable>(_ type: T.Type, from queryItems: [URLQueryItem]) throws -> T {
        let queryItemsDecoding = QueryItemsDecoding(from: .init(queryItems: queryItems))
        return try T(from: queryItemsDecoding)
    }
}

private struct QueryItemsDecoding: Decoder {
    fileprivate final class QueryItems {
        var queryItems: [URLQueryItem]

        init(queryItems: [URLQueryItem]) {
            self.queryItems = queryItems
        }

        func decode(key codingKey: CodingKey) -> String? {
            let name = codingKey.stringValue
            return queryItems.first { $0.name == name }?.value
        }
    }

    fileprivate var queryItems: QueryItems

    init(from queryItems: QueryItems) {
        self.queryItems = queryItems
    }

    var codingPath: [any CodingKey] = []

    var userInfo: [CodingUserInfoKey: Any] = [:]

    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key: CodingKey {
        let container = QueryItemsKeyedDecoding<Key>(from: queryItems)
        return KeyedDecodingContainer(container)
    }

    func unkeyedContainer() throws -> any UnkeyedDecodingContainer {
        fatalError("Only flat primitives are supported")
    }

    func singleValueContainer() throws -> any SingleValueDecodingContainer {
        fatalError("Only flat primitives are supported")
    }
}

private struct QueryItemsKeyedDecoding<Key: CodingKey>: KeyedDecodingContainerProtocol {
    private let queryItems: QueryItemsDecoding.QueryItems

    init(from queryItems: QueryItemsDecoding.QueryItems) {
        self.queryItems = queryItems
    }

    var codingPath: [any CodingKey] = []

    var allKeys: [Key] {
        queryItems.queryItems.compactMap { Key(stringValue: $0.name) }
    }

    func contains(_ key: Key) -> Bool {
        queryItems.queryItems.contains { $0.name == key.stringValue }
    }

    func decodeNil(forKey key: Key) throws -> Bool {
        fatalError("Only String can be decoded")
    }

    func decode(_ type: String.Type, forKey key: Key) throws -> String {
        guard let item = queryItems.queryItems.first(where: { $0.name == key.stringValue }) else {
            throw DecodingError.keyNotFound(key, .init(codingPath: codingPath, debugDescription: ""))
        }

        guard let value = item.value else {
            throw DecodingError.valueNotFound(type, .init(codingPath: codingPath, debugDescription: ""))
        }

        return value
    }

    func decode<T>(_ type: T.Type, forKey key: Key) throws -> T where T: Decodable {
        fatalError("Only String can be decoded")
    }

    func nestedContainer<NestedKey>(
        keyedBy type: NestedKey.Type,
        forKey key: Key
    ) throws -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey {
        fatalError("Only flat primitives are supported")
    }

    func nestedUnkeyedContainer(forKey key: Key) throws -> any UnkeyedDecodingContainer {
        fatalError("Only flat primitives are supported")
    }

    func superDecoder() throws -> any Decoder {
        fatalError("Only flat primitives are supported")
    }

    func superDecoder(forKey key: Key) throws -> any Decoder {
        fatalError("Only flat primitives are supported")
    }
}
