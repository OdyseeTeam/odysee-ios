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
    var defaultChannelId: String?

    var otherValues: [String: Value]
    var otherSettings: [String: Value]

    struct Following: Codable {
        var notificationsDisabled: Bool
        var uri: LbryUri

        init(notificationsDisabled: Bool, uri: LbryUri) {
            self.notificationsDisabled = notificationsDisabled
            self.uri = uri
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: SharedPreference.Following.CodingKeys.self)
            notificationsDisabled = (try? container.decode(Bool.self, forKey: .notificationsDisabled)) ?? true
            uri = try container.decode(LbryUri.self, forKey: .uri)
        }
    }

    init() {
        subscriptions = []
        following = []
        blocked = []
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

    init(from decoder: Decoder) throws {
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

        subscriptions = try value.decode([LbryUri].self, forKey: .subscriptions)
        following = try value.decode([Following].self, forKey: .following)
        blocked = try value.decode([LbryUri].self, forKey: .blocked)
        defaultChannelId = try? settings.decode(String.self, forKey: .defaultChannelId)
    }

    func encode(to encoder: Encoder) throws {
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
        try value.encode(subscriptions, forKey: .subscriptions)
        try value.encode(following, forKey: .following)
        try value.encode(blocked, forKey: .blocked)
        try settings.encode(defaultChannelId, forKey: .defaultChannelId)
    }
}
