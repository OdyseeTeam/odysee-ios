//
//  SharedPreference+PlaylistTest.swift
//  OdyseeTests
//
//  Created by Keith Toh on 12/05/2026.
//

import Foundation
import Odysee
import Testing

struct SharedPreference_PlaylistTest {
    @Test func `Decode no Tags`() throws {
        let json = """
        {
            "id": "abc",
            "items": [],
            "name": "abc",
            "type": "playlist",
            "updatedAt": 0
        }
        """

        _ = try JSONDecoder().decode(SharedPreference.Collection.self, from: json.data)
    }

    @Test func `Decode String Tags`() throws {
        let json = """
        {
            "id": "abc",
            "items": [],
            "name": "abc",
            "tags": [
                "a",
                "b",
                "c"
            ],
            "type": "playlist",
            "updatedAt": 0
        }
        """

        let collection = try JSONDecoder().decode(SharedPreference.Collection.self, from: json.data)

        let tags = try #require(collection.tags)
        #expect(tags.elementsEqual(["a", "b", "c"]))
    }

    @Test func `Decode Object Tags`() throws {
        let json = """
        {
            "id": "abc",
            "items": [],
            "name": "abc",
            "tags": [
                { "name": "a" },
                { "name": "b" },
                { "name": "c" }
            ],
            "type": "playlist",
            "updatedAt": 0
        }
        """

        let collection = try JSONDecoder().decode(SharedPreference.Collection.self, from: json.data)

        let tags = try #require(collection.tags)
        #expect(tags.elementsEqual(["a", "b", "c"]))
    }

    @Test func `Encode Tags`() throws {
        let testTags = ["a", "b", "c"]

        let collection = SharedPreference.Collection(
            id: "abc",
            name: "abc",
            tags: testTags,
            type: .playlist,
            updatedAt: 0
        )

        let data = try JSONEncoder().encode(collection)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let tags = try #require(object["tags"] as? [[String: String]])

        #expect(tags.compactMap(\.["name"]).elementsEqual(testTags))
    }
}
