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
    public struct Collection: Codable {
        public var collectionId: String
        public var items: Items
        public var name: String
        public var title: String?
        public var description: String?
        @Tags public var tags: [String]?
        public var thumbnail: Thumbnail?
        public var type: CollectionType
        public var createdAt: Int?
        public var updatedAt: Int
        public var itemCount: Int?
        /// if copied, claimId of original collection
        public var sourceId: String?

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
        public struct Items: Codable, Equatable {
            var uris: [LbryUri]

            public init(uris: [LbryUri]) {
                self.uris = uris
            }

            public init(from decoder: any Decoder) throws {
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

            public func encode(to encoder: any Encoder) throws {
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

        public struct Thumbnail: Codable, Equatable {
            var url: URL?
        }

        public enum CollectionType: String, Codable {
            case playlist
            /// > 'COL_TYPES.COLLECTION', I believe, is the placeholder for mixed-type collection.\
            /// <https://github.com/OdyseeTeam/odysee-frontend/blob/c605de2a2f461d61fcc4745dd1008510ef1e3737/ui/util/collections.ts#L51>
            case collection
        }

        enum CodingKeys: String, CodingKey {
            case collectionId = "id"
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

        // MARK: Metadata

        public enum Origin: String {
            case builtin
            case edited
            case saved
            case unpublished
            case published
            case claim
        }

        var origin: Origin?

        // MARK: Helpers

        var titleOrName: String {
            get {
                title ?? name
            }
            set {
                title = newValue
                name = newValue
            }
        }

        var count: Int {
            items.claimIds?.count ?? items.uris.count
        }

        // MARK: Representing public playlists

        /// Preserves for ``SharedPreference/Collection/asClaim``
        var originalClaim: Claim?

        public init(
            id: String,
            items: Items = .init(uris: []),
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
            originalClaim: Claim? = nil,
            origin: Origin? = nil
        ) {
            collectionId = id
            self.items = items
            self.name = name
            self.title = title
            self.description = description
            _tags = Tags(tags)
            self.thumbnail = thumbnail
            self.type = type
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.itemCount = itemCount
            self.sourceId = sourceId
            self.originalClaim = originalClaim

            self.origin = origin
        }

        // MARK: Fields for Publishing

        var publishChannel: Claim?
    }
}

extension SharedPreference.CollectionGroup {
    var items: [SharedPreference.Collection] {
        Array(values)
    }
}

// MARK: - Setting Metadata

extension SharedPreference.CollectionGroup {
    func withOrigin(_ origin: SharedPreference.Collection.Origin) -> Self {
        reduce(into: [:]) { result, element in
            var collection = element.value
            collection.origin = origin
            result[element.key] = collection
        }
    }
}

// MARK: - Protocol Conformances

extension SharedPreference.Collection: Equatable {}

extension SharedPreference.Collection: Identifiable {
    /// Collections from different origins but with the same id (e.g. `published` and `edited`) are unique
    public var id: String {
        (origin?.rawValue ?? "") + collectionId
    }
}

// MARK: - Collection as Claim

extension SharedPreference.Collection {
    var asClaim: Claim {
        var claim = originalClaim ?? Claim(value: .init())

        claim.claimId = collectionId
        claim.value?.title = titleOrName
        claim.value?.claims = items.claimIds ?? items.uris.compactMap(\.streamClaimId)
        claim.valueType = .collection

        return claim
    }
}

// MARK: - Claim as Collection

extension Claim {
    func asCollection(origin: SharedPreference.Collection.Origin) -> SharedPreference.Collection? {
        guard let claimId, let name else {
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
            items: .init(claimIds: value?.claims),
            name: name,
            title: value?.title,
            description: value?.description,
            tags: value?.tags,
            thumbnail: thumbnail,
            type: .playlist,
            createdAt: releaseTime,
            updatedAt: releaseTime,
            itemCount: value?.claims?.count ?? 0,
            originalClaim: self,

            origin: origin
        )
    }
}

// MARK: - Collection Logic

extension SharedPreference.Collection {
    var isPublic: Bool {
        originalClaim != nil
    }

    var canEdit: Bool {
        [.builtin, .edited, .unpublished, .published].contains(origin)
    }

    var canDelete: Bool {
        [.edited, .saved, .unpublished, .published].contains(origin)
    }

    var isPublished: Bool {
        [.edited, .published].contains(origin)
    }
}
