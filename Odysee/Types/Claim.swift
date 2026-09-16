//
//  Claim.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 02/11/2020.
//

import Foundation

enum ClaimType: String, Codable {
    case channel
    case stream
    case repost
    case collection
}

enum StreamType: String, Codable {
    case audio
    case binary
    case document
    case image
    case model
    case video
}

@propertyWrapper
final class ClaimBox: Decodable {
    let wrappedValue: Claim?

    required init(from decoder: Decoder) throws {
        wrappedValue = try Claim(from: decoder)
    }

    init(wrappedValue: Claim?) {
        self.wrappedValue = wrappedValue
    }
}

extension KeyedDecodingContainer {
    /// Handle decoding property wrapper with optional wrapped value
    /// <https://forums.swift.org/t/using-property-wrappers-with-codable/29804/12>
    func decode(_ type: ClaimBox.Type, forKey key: Self.Key) throws -> ClaimBox {
        try decodeIfPresent(type, forKey: key) ?? ClaimBox(wrappedValue: nil)
    }
}

public struct Claim: Decodable {
    var address: String?
    var amount: String?
    var canonicalUrl: String?
    var claimId: String?
    var claimOp: String?
    var confirmations: Int?
    var height: Int?
    var isChannelSignatureValid: Bool?
    var meta: Meta?
    var name: String?
    var normalizedName: String?
    var nout: Int?
    var permanentUrl: String?
    var shortUrl: String?
    @ClaimBox var signingChannel: Claim? = nil
    @ClaimBox var repostedClaim: Claim? = nil
    var timestamp: Int64?
    var txid: String?
    var type: String?
    var value: Metadata?
    var valueType: ClaimType?

    private enum CodingKeys: String, CodingKey {
        case address
        case amount
        case canonicalUrl
        case claimId
        case claimOp
        case confirmations
        case height
        case isChannelSignatureValid
        case meta
        case name
        case normalizedName
        case nout
        case permanentUrl
        case shortUrl
        case signingChannel
        case repostedClaim
        case timestamp
        case txid
        case type
        case value
        case valueType
    }

    struct Metadata: Decodable {
        var title: String?
        var description: String?
        var thumbnail: Resource?
        var languages: [String]?
        var tags: [String]?
        var locations: [Location]?

        // channel
        var publicKey: String?
        var publicKeyId: String?
        var cover: Resource?
        var email: String?
        var websiteUrl: String?
        var featured: [String]?

        // stream
        var license: String?
        var licenseUrl: String?
        var releaseTime: String?
        var author: String?
        var fee: Fee?
        var streamType: String?
        var source: Source?
        var video: StreamInfo?
        var audio: StreamInfo?
        var image: StreamInfo?
        var software: StreamInfo?

        // collection
        var claims: [String]?
    }

    struct Source: Decodable {
        var sdHash: String?
        var mediaType: String?
        var hash: String?
        var name: String?
        var size: String?
    }

    struct Fee: Decodable {
        var amount: String?
        var currency: String?
        var address: String?
    }

    struct Location: Decodable {
        var country: String?
    }

    struct Resource: Decodable {
        // TODO: make this `URL?`
        var url: String?
    }

    struct StreamInfo: Decodable {
        var duration: Int64?
        var height: Int64?
        var width: Int64?
        var os: String?
    }

    struct Meta: Decodable {
        var effectiveAmount: String?
    }

    var outpoint: Outpoint? {
        if let txid = txid, let nout = nout {
            return Outpoint(txid: txid, index: nout)
        } else {
            return nil
        }
    }

    var titleOrName: String? {
        if let title = value?.title {
            return title
        }
        return name
    }

    // MARK: - UI Flags

    var selected: Bool = false
    var featured: Bool = false
    var lastPosition: UInt = 0
}

// MARK: - Protocol Conformances

extension Claim: Equatable {
    public static func == (lhs: Claim, rhs: Claim) -> Bool {
        return lhs.claimId == rhs.claimId
    }
}

extension Claim: Hashable {
    public func hash(into hasher: inout Hasher) {
        claimId.hash(into: &hasher)
    }
}

extension Claim: Identifiable {
    public var id: String? {
        return claimId
    }
}

extension Claim: Comparable {
    public static func < (lhs: Claim, rhs: Claim) -> Bool {
        guard let lhs = lhs.titleOrName, let rhs = rhs.titleOrName else {
            return false
        }
        return lhs.localizedCompare(rhs) == .orderedAscending
    }
}

// MARK: - Predefined Anonymous (all equal due to "anonymous" claimId)

extension Claim {
    static let anonymous = Claim(
        claimId: "anonymous",
        name: "Anonymous"
    )
}
