//
//  SharedPreference.swift
//  Odysee
//
//  Created by Keith Toh on 26/12/2025.
//

import Foundation
import ValueCodable

public struct SharedPreference: Codable {
    @Following var following: Follows
    var blocked: [LbryUri]
    var defaultChannelId: String?
    var builtinCollections: CollectionGroup
    var editedCollections: CollectionGroup
    var savedCollectionIds: [String]
    var unpublishedCollections: CollectionGroup

    var otherValues: [String: Value]
    var otherSettings: [String: Value]

    private static var defaultBuiltinCollections: CollectionGroup {
        let now = Int(Date().timeIntervalSince1970)

        return [
            "watchlater": .init(
                id: "watchlater",
                name: "Watch Later",
                type: .playlist,
                createdAt: now,
                updatedAt: now
            ),
            "favorites": .init(
                id: "favorites",
                name: "Favorites",
                type: .playlist,
                createdAt: now,
                updatedAt: now
            ),
        ]
    }

    init() {
        _following = .init([:])
        blocked = []
        builtinCollections = Self.defaultBuiltinCollections
        editedCollections = [:]
        savedCollectionIds = []
        unpublishedCollections = [:]

        otherValues = [:]
        otherSettings = [:]
    }

    enum CodingKeys: String, CodingKey {
        case version
        case type
        case value

        struct Value: CodingKey {
            static let subscriptions = Value(stringValue: "subscriptions")
            static let following = Value(stringValue: "following")
            static let blocked = Value(stringValue: "blocked")
            static let builtinCollections = Value(stringValue: "builtinCollections")
            static let editedCollections = Value(stringValue: "editedCollections")
            static let savedCollectionIds = Value(stringValue: "savedCollectionIds")
            static let unpublishedCollections = Value(stringValue: "unpublishedCollections")
            static let settings = Value(stringValue: "settings")

            var stringValue: String

            init(stringValue: String) {
                self.stringValue = stringValue
            }

            var intValue: Int?

            init?(intValue: Int) {
                self.init(stringValue: "\(intValue)")
                self.intValue = intValue
            }

            struct Settings: CodingKey {
                static let defaultChannelId = Settings(stringValue: "active_channel_claim")

                var stringValue: String

                init(stringValue: String) {
                    self.stringValue = stringValue
                }

                var intValue: Int?

                init?(intValue: Int) {
                    self.init(stringValue: "\(intValue)")
                    self.intValue = intValue
                }
            }
        }
    }

    static let type = "object"
    static let version = "0.1"

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard try container.decode(String.self, forKey: .version) == Self.version else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: [CodingKeys.version],
                debugDescription: #""version" is not "\#(Self.version)""#
            ))
        }
        guard try container.decode(String.self, forKey: .type) == Self.type else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: [CodingKeys.type],
                debugDescription: #""type" is not "\#(Self.type)""#
            ))
        }
        let value = try container.nestedContainer(keyedBy: CodingKeys.Value.self, forKey: .value)
        let settings = try value.nestedContainer(keyedBy: CodingKeys.Value.Settings.self, forKey: .settings)

        otherValues = [:]
        for key in value.allKeys {
            otherValues[key.stringValue] = try value.decode(Value.self, forKey: key)
        }
        otherSettings = [:]
        for key in settings.allKeys {
            otherSettings[key.stringValue] = try settings.decode(Value.self, forKey: key)
        }

        _following = try value.decode(Following.self, forKey: .following)
        blocked = try value.decode([LbryUri].self, forKey: .blocked)
        builtinCollections = try value.decodeIfPresent(CollectionGroup.self, forKey: .builtinCollections)
            .orElse(Self.defaultBuiltinCollections)
            .withOrigin(.builtin)
        editedCollections = try value.decodeIfPresent(CollectionGroup.self, forKey: .editedCollections)
            .orElse([:])
            .withOrigin(.edited)
        savedCollectionIds = try value.decodeIfPresent([String].self, forKey: .savedCollectionIds) ?? []
        unpublishedCollections = try value.decodeIfPresent(CollectionGroup.self, forKey: .unpublishedCollections)
            .orElse([:])
            .withOrigin(.unpublished)
        defaultChannelId = try settings.decodeIfPresent(String.self, forKey: .defaultChannelId)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        var value = container.nestedContainer(keyedBy: CodingKeys.Value.self, forKey: .value)
        var settings = value.nestedContainer(keyedBy: CodingKeys.Value.Settings.self, forKey: .settings)

        for (key, otherValue) in otherValues where key != CodingKeys.Value.settings.stringValue {
            try value.encode(otherValue, forKey: CodingKeys.Value(stringValue: key))
        }
        for (key, otherSetting) in otherSettings {
            try settings.encode(otherSetting, forKey: CodingKeys.Value.Settings(stringValue: key))
        }

        try container.encode(Self.type, forKey: .type)
        try container.encode(Self.version, forKey: .version)
        try value.encode(Array(following.keys), forKey: .subscriptions)
        try value.encode(_following, forKey: .following)
        try value.encode(blocked, forKey: .blocked)
        try value.encode(builtinCollections, forKey: .builtinCollections)
        try value.encode(editedCollections, forKey: .editedCollections)
        try value.encode(savedCollectionIds, forKey: .savedCollectionIds)
        try value.encode(unpublishedCollections, forKey: .unpublishedCollections)
        try settings.encode(defaultChannelId, forKey: .defaultChannelId)
    }
}
