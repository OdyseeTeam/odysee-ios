//
//  AccountResult.swift
//  Odysee
//
//  Created by Keith Toh on 24/12/2025.
//

import Foundation

typealias FileLastPositionsResult = [String: UInt]

struct UserNewResult: Decodable {
    var authToken: String
}

struct UserExistsResult: Decodable {
    var hasPassword: Bool
}

struct SyncGetResult: Decodable {
    var changed: Bool
    var hash: String?
    var data: String?
}

struct SyncSetResult: Decodable {
    var changed: Bool
    var hash: String?
}

struct LocaleGetResult: Decodable {
    var continent: String
    var country: String
    var gdprRequired: Bool
    var isEUMember: Bool
    var isGoogleLimited: Bool

    enum CodingKeys: String, CodingKey {
        case continent
        case country
        case gdprRequired
        case isEUMember = "isEuMember"
        case isGoogleLimited
    }
}

struct GeoBlockedListResult: Decodable {
    typealias Rules = [Claim.ID: [Rule]]
    var rules: Rules

    struct Rule {
        var scope: Scope
        var id: String
        var trigger: String?
        var reason: String?
        var message: String?

        static let localeUnknown: Rule = .init(
            scope: .special,
            id: "",
            message: "Couldn't fetch legally required location data to access this content, please try again later or reach out to hello@odysee.com if the issue continues."
        )
    }

    enum Scope {
        case country
        case continent
        case special
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        // FIXME: Claim.ID when non optional
        let result = try container.decode([Type: [String: Geographies]].self)

        rules = [:]

        for restrictions in result.values {
            for (claimId, geographies) in restrictions {
                var claimRules = [Rule]()

                if let countryRestrictions = geographies.countries {
                    claimRules.append(contentsOf: rules(from: countryRestrictions, for: .country))
                }
                if let continentRestrictions = geographies.continents {
                    claimRules.append(contentsOf: rules(from: continentRestrictions, for: .continent))
                }
                if let specialRestrictions = geographies.specials {
                    claimRules.append(contentsOf: rules(from: specialRestrictions, for: .special))
                }

                rules[claimId] = claimRules
            }
        }
    }

    private enum `Type`: String, Decodable, CodingKeyRepresentable {
        case videos
        case livestreams
    }

    private struct Geographies: Decodable {
        var countries: [Restriction]?
        var continents: [Restriction]?
        var specials: [Restriction]?
    }

    private struct Restriction: Decodable {
        var id: String
        var trigger: String?
        var reason: String?
        var message: String?
    }

    private func rules(from restrictions: [Restriction], for scope: Scope) -> [Rule] {
        restrictions.map {
            .init(
                scope: scope,
                id: $0.id,
                trigger: $0.trigger,
                reason: $0.reason,
                message: $0.message
            )
        }
    }
}

typealias NotificationListResult = [Notification]

struct ViewHistory: Decodable {
    var claimId: String
    var claimName: String
    var lastPosition: UInt
}

typealias YtTransferResult = [YtTransferResultElement]

struct YtTransferResultElement: Decodable {
    var channel: YoutubeChannel?
    var totalPublishedVideos: Int
    var totalTransferred: Int
    var changed: Bool
}

struct FileListClaimIdsResult: Decodable {
    typealias Tag = String
    typealias ClaimIdsMap = [Claim.ID: Tag]
    var claimIds: ClaimIdsMap

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let items = try container.decode([ClaimIdItem].self)

        claimIds = .init(items.map { ($0.claimId, $0.tag) }, uniquingKeysWith: { _, last in last })
    }

    struct ClaimIdItem: Decodable {
        var claimId: String
        var tag: String

        enum CodingKeys: String, CodingKey {
            case claimId
            case tag = "tagName"
        }
    }
}
