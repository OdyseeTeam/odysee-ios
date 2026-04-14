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
        }

        struct Thumbnail: Codable {
            var url: URL?
        }

        enum CollectionType: String, Codable {
            case playlist
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
        Claim(
            claimId: id,
            value: .init(
                title: title ?? name, // FIXME:
                claims: items.uris.compactMap(\.streamClaimId),
            ),
            valueType: .collection,
        )
    }
}
