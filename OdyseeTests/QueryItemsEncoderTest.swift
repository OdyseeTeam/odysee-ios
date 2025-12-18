//
//  QueryItemsEncoderTests.swift
//  OdyseeTests
//
//  Created by Keith Toh on 18/12/2025.
//

import Foundation
import Odysee
import Testing

struct QueryItemsEncoderTests {
    struct Params: Codable {
        var email: String
        var password: String
    }

    @Test func encode() async throws {
        let items = try! QueryItemsEncoder().encode(Params(email: "test@example.com", password: "123"))
        var components = URLComponents()
        components.queryItems = items
        #expect(components.percentEncodedQuery == "email=test@example.com&password=123")
    }

    /// fatalError expected
    /*
    struct NestedParams: Codable {
        var id: Int
        var params: Params
    }

    // Nested should never be used, but test to make sure it doesn't break
    @Test func encodeNested() async throws {
        let items = try! QueryItemsEncoder().encode(NestedParams(id: 0, params: Params(email: "test@example.com", password: "123")))
        var components = URLComponents()
        components.queryItems = items
        #expect(components.percentEncodedQuery == "id=0&params.email=test@example.com&params.password=123")
    }

    struct UnkeyedStruct: Encodable {
        var array: [Int]
    }

    @Test func encodeUnkeyed() async throws {
        print(try! QueryItemsEncoder().encode([1, 2, 3]))
        print(try! QueryItemsEncoder().encode(UnkeyedStruct(array: [4, 5, 6])))
    }
    */

    struct OptionalParams: Codable {
        var maybe: Bool?
    }

    @Test func encodeOptional() async throws {
        var components = URLComponents()
        components.queryItems = [URLQueryItem(name: "test", value: nil), URLQueryItem(name: "test2", value: "abc")]
        #expect(components.percentEncodedQuery == "test&test2=abc")

        var items = try! QueryItemsEncoder().encode(OptionalParams(maybe: nil))
        components = URLComponents()
        components.queryItems = items
        #expect(components.percentEncodedQuery == "")

        items = try! QueryItemsEncoder().encode(OptionalParams(maybe: true))
        components = URLComponents()
        components.queryItems = items
        #expect(components.percentEncodedQuery == "maybe=true")
    }
}
