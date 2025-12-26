//
//  SharedPreference.swift
//  Odysee
//
//  Created by Keith Toh on 26/12/2025.
//

import Foundation
import ValueCodable

struct SharedPreference: Codable {
    var subscriptions: [LbryUri]
    var following: [Following]
    var blocked: [LbryUri]
    var defaultChannelId: String

    var otherValues: [String: Value]
    var otherSettings: [String: Value]

    struct Following: Codable {
        var notificationsDisabled: Bool
        var uri: LbryUri
    }

    enum CodingKeys: String, CodingKey {
        case shared

        enum Shared: String, CodingKey {
            case version
            case type
            case value

            struct Value: CodingKey {
                static let subscriptions = Value(stringValue: "subscriptions")
                static let following = Value(stringValue: "following")
                static let blocked = Value(stringValue: "blocked")
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
    }

    static let type = "object"
    static let version = "0.1"

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let shared = try container.nestedContainer(keyedBy: CodingKeys.Shared.self, forKey: .shared)
        guard try shared.decode(String.self, forKey: .version) == Self.version else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: [CodingKeys.shared, CodingKeys.Shared.version],
                debugDescription: #""version" is not "\#(Self.version)""#
            ))
        }
        guard try shared.decode(String.self, forKey: .type) == Self.type else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: [CodingKeys.shared, CodingKeys.Shared.type],
                debugDescription: #""type" is not "\#(Self.type)""#
            ))
        }
        let value = try shared.nestedContainer(keyedBy: CodingKeys.Shared.Value.self, forKey: .value)
        let settings = try value.nestedContainer(keyedBy: CodingKeys.Shared.Value.Settings.self, forKey: .settings)

        otherValues = [:]
        for key in value.allKeys {
            otherValues[key.stringValue] = try value.decode(Value.self, forKey: key)
        }
        otherSettings = [:]
        for key in settings.allKeys {
            otherSettings[key.stringValue] = try settings.decode(Value.self, forKey: key)
        }

        subscriptions = try value.decode([LbryUri].self, forKey: .subscriptions)
        following = try value.decode([Following].self, forKey: .following)
        blocked = try value.decode([LbryUri].self, forKey: .blocked)
        defaultChannelId = try settings.decode(String.self, forKey: .defaultChannelId)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.Shared.self)
        var value = container.nestedContainer(keyedBy: CodingKeys.Shared.Value.self, forKey: .value)
        var settings = value.nestedContainer(keyedBy: CodingKeys.Shared.Value.Settings.self, forKey: .settings)

        for (key, otherValue) in otherValues where key != CodingKeys.Shared.Value.settings.stringValue {
            try value.encode(otherValue, forKey: CodingKeys.Shared.Value(stringValue: key))
        }
        for (key, otherSetting) in otherSettings {
            try settings.encode(otherSetting, forKey: CodingKeys.Shared.Value.Settings(stringValue: key))
        }

        try container.encode(Self.type, forKey: .type)
        try container.encode(Self.version, forKey: .version)
        try value.encode(subscriptions, forKey: .subscriptions)
        try value.encode(following, forKey: .following)
        try value.encode(blocked, forKey: .blocked)
        try settings.encode(defaultChannelId, forKey: .defaultChannelId)
    }
}
