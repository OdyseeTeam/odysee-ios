//
//  SharedPreference+Playlist.swift
//  Odysee
//
//  Created by Keith Toh on 09/04/2026.
//

import Foundation
import RegexBuilder

extension SharedPreference {
    typealias CollectionGroup = [String: Collection]

    /// https://github.com/OdyseeTeam/odysee-frontend/blob/3f320e22446261ff22475641a555c6b316d68e4f/flow-typed/Collections.js#L1-L21
    struct Collection: Codable {
        /// Not UUID to match CollectionGroup key, because [it's unsupported]( https://github.com/swiftlang/swift-corelibs-foundation/issues/3614#issuecomment-1118348969)
        var id: String
        var items: Items
        var name: String
        var title: String?
        var description: String?
        var tags: [String]?
        var thumbnail: Thumbnail?
        var type: CollectionType
        var createdAt: Int?
        var updatedAt: Int
        var itemCount: Int?
        /// if copied, claimId of original collection
        var sourceId: String?

        /// The array of items in the playlist
        ///
        /// This is meant to be an array of ``LbryUri``, however, due to an error in the odysee-android Java app,
        /// some collections may have items like `OdyseeCollection.Item(url=lbry://..., itemOrder=1)`.
        /// [[1]](https://github.com/OdyseeTeam/odysee-android/blob/2f8e54e9371cd50a9b41470b0307f22635469367/app/src/main/java/com/odysee/app/model/OdyseeCollection.java#L104)
        /// [[2]](https://github.com/OdyseeTeam/odysee-android/blob/2f8e54e9371cd50a9b41470b0307f22635469367/app/src/main/java/com/odysee/app/utils/Helper.java#L174-L180)
        /// [[3]](https://github.com/OdyseeTeam/odysee-android/blob/2f8e54e9371cd50a9b41470b0307f22635469367/app/src/main/java/com/odysee/app/model/OdyseeCollection.java#L169-L180)
        /// [[4]](https://projectlombok.org/features/ToString#:~:text=and%20members%20of%20the%20same%20rank%20are%20printed%20in%20the%20same%20order%20they%20appear%20in%20the%20source%20file.)
        ///
        /// This struct attempts to decode such items, and present both types of items under the ``uris`` field.
        struct Items: Codable {
            var uris: [LbryUri]

            init(uris: [LbryUri]) {
                self.uris = uris
            }

            init(from decoder: any Decoder) throws {
                var container = try decoder.unkeyedContainer()

                var uris = [LbryUri]()
                if let count = container.count {
                    uris.reserveCapacity(count)
                }

                var stringsToTry = [String]()

                while !container.isAtEnd {
                    do {
                        try uris.append(container.decode(LbryUri.self))
                    } catch is LbryUriError {
                        try stringsToTry.append(container.decode(String.self))
                    }
                }

                if #available(iOS 16, *) {
                    let regex = Regex {
                        "OdyseeCollection.Item(url="

                        Capture {
                            OneOrMore(.any)
                        } transform: { String($0) }

                        ", itemOrder="
                        OneOrMore(.digit)
                        ")"
                    }

                    for string in stringsToTry {
                        if let match = try regex.wholeMatch(in: string) {
                            try uris.append(LbryUri.parse(url: match.1, requireProto: true))
                        }
                    }
                }

                self.uris = uris
            }

            func encode(to encoder: any Encoder) throws {
                var container = encoder.singleValueContainer()
                try container.encode(uris)
            }

            // MARK: - Collection Items from Claim

            var claimIds: [String]?

            init(claimIds: [String]?) {
                uris = []
                self.claimIds = claimIds
            }
        }

        struct Thumbnail: Codable {
            var url: URL?
        }

        enum CollectionType: String, Codable {
            case playlist
        }

        enum CodingKeys: String, CodingKey {
            case id
            case items
            case name
            case title
            case description
            case tags
            case thumbnail
            case type
            case createdAt
            case updatedAt
            case itemCount
            case sourceId
        }

        // MARK: - Helpers

        var titleOrName: String {
            title ?? name
        }

        var count: Int {
            itemCount ?? items.uris.count
        }

        // MARK: - Representing public playlists

        /// Preserves for ``SharedPreference/Collection/asClaim``
        var originalClaim: Claim?

        var isPublic: Bool {
            originalClaim != nil
        }

        init(
            id: String,
            items: Items,
            name: String,
            title: String? = nil,
            description: String? = nil,
            tags: [String]? = nil,
            thumbnail: Thumbnail? = nil,
            type: CollectionType,
            createdAt: Int? = nil,
            updatedAt: Int,
            itemCount: Int? = nil,
            sourceId: String? = nil,
            originalClaim: Claim? = nil
        ) {
            self.id = id
            self.items = items
            self.name = name
            self.title = title
            self.description = description
            self.tags = tags
            self.thumbnail = thumbnail
            self.type = type
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.itemCount = itemCount
            self.sourceId = sourceId
            self.originalClaim = originalClaim
        }
    }
}

// MARK: - Protocol Conformances

extension SharedPreference.Collection: Equatable {
    static func == (lhs: SharedPreference.Collection, rhs: SharedPreference.Collection) -> Bool {
        return lhs.id == rhs.id
    }
}

extension SharedPreference.Collection: Identifiable {}

// MARK: - Collection as Claim

extension SharedPreference.Collection {
    var asClaim: Claim {
        originalClaim ?? Claim(
            claimId: id,
            value: .init(
                title: titleOrName,
                claims: items.uris.compactMap(\.streamClaimId),
            ),
            valueType: .collection,
        )
    }
}

// MARK: - Claim as Collection

extension Claim {
    var asCollection: SharedPreference.Collection? {
        guard let claimId, let titleOrName else {
            return nil
        }

        let releaseTime = if let releaseTime = value?.releaseTime,
                             let releaseTimestamp = Int(releaseTime)
        {
            releaseTimestamp
        } else {
            Int(timestamp ?? 0)
        }

        let thumbnail: SharedPreference.Collection.Thumbnail? = if let thumbnail = value?.thumbnail?.url {
            .init(url: URL(string: thumbnail))
        } else {
            nil
        }

        return SharedPreference.Collection(
            id: claimId,
            // Only used for claim_search for thumbnail, if needed
            items: .init(claimIds: value?.claims),
            name: titleOrName,
            title: value?.title,
            description: value?.description,
            tags: value?.tags,
            thumbnail: thumbnail,
            type: .playlist,
            createdAt: releaseTime,
            updatedAt: releaseTime,
            itemCount: value?.claims?.count ?? 0,
            originalClaim: self
        )
    }
}
