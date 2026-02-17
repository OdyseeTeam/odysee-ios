//
//  QueryItemsCoderTest.swift
//  OdyseeTests
//
//  Created by Keith Toh on 18/12/2025.
//

import Foundation
import Odysee
import Testing

struct QueryItemsCoderTests {
    struct Params: Codable, Equatable {
        var email: String
        var password: String
    }

    @Test func encode() async throws {
        let items = try! QueryItemsEncoder().encode(Params(email: "test@example.com", password: "123"))
        var components = URLComponents()
        components.queryItems = items
        #expect(components.percentEncodedQuery == "email=test@example.com&password=123")
    }

    @Test func decode() async throws {
        var components = URLComponents()
        components.percentEncodedQuery = "email=test@example.com&password=123"
        let params = try! QueryItemsDecoder().decode(Params.self, from: components.queryItems!)
        #expect(params == Params(email: "test@example.com", password: "123"))
    }

    struct InvalidURLQueryItemsError: Error {}

    enum ReturnURL: Decodable, Equatable {
        case success
        case error(message: String)

        enum CodingKeys: String, CodingKey {
            case token = "success_token"
            case error
            case errorMessage = "error_message"
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            if container.contains(.token) {
                self = .success
                return
            }

            if (try? container.decode(String.self, forKey: .error)) == "true",
               let message = try? container.decode(String.self, forKey: .errorMessage)
            {
                self = .error(message: message)
                return
            }

            throw InvalidURLQueryItemsError()
        }
    }

    @Test func decodeEnum_success() async throws {
        var components = URLComponents()
        components.percentEncodedQuery = "success_token=deadbeef"
        let returnUrl = try! QueryItemsDecoder().decode(ReturnURL.self, from: components.queryItems!)
        #expect(returnUrl == .success)
    }

    @Test func decodeEnum_error() async throws {
        var components = URLComponents()
        components.percentEncodedQuery = "error=true&error_message=hellorld%20help@odysee.com"
        let returnUrl = try! QueryItemsDecoder().decode(ReturnURL.self, from: components.queryItems!)
        #expect(returnUrl == .error(message: "hellorld help@odysee.com"))
    }

    @Test func decodeEnum_unknown() async throws {
        var components = URLComponents()
        components.percentEncodedQuery = "unknown=indeed"
        #expect(throws: InvalidURLQueryItemsError.self) {
            try QueryItemsDecoder().decode(ReturnURL.self, from: components.queryItems!)
        }
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
