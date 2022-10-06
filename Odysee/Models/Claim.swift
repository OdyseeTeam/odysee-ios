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

class Claim: Decodable, Equatable, Hashable {
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
    var signingChannel: Claim?
    var repostedClaim: Claim?
    var timestamp: Int64?
    var txid: String?
    var type: String?
    var value: Metadata?
    var valueType: ClaimType?
    var selected: Bool = false
    var featured: Bool = false

    private enum CodingKeys: String, CodingKey {
        case address
        case amount
        case canonicalUrl = "canonical_url"
        case claimId = "claim_id"
        case claimOp = "claim_op"
        case confirmations
        case height
        case isChannelSignatureValid = "is_channel_signature_valid"
        case meta
        case name
        case normalizedName = "normalized_name"
        case nout
        case permanentUrl = "permanent_url"
        case shortUrl = "short_url"
        case signingChannel = "signing_channel"
        case repostedClaim = "reposted_claim"
        case timestamp
        case txid
        case value
        case valueType = "value_type"
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

        private enum CodingKeys: String, CodingKey {
            case title
            case description
            case thumbnail
            case languages
            case tags
            case locations
            case publicKey = "public_key"
            case publicKeyId = "public_key_id"
            case cover
            case email
            case websiteUrl = "website_url"
            case featured
            case license
            case licenseUrl = "license_url"
            case releaseTime = "release_time"
            case author
            case fee
            case streamType = "stream_type"
            case source
            case video
            case audio
            case image
            case software
            case claims
        }
    }

    struct Source: Decodable {
        var sdHash: String?
        var mediaType: String?
        var hash: String?
        var name: String?
        var size: String?

        private enum CodingKeys: String, CodingKey {
            case sdHash = "sd_hash"
            case mediaType = "media_type"
            case hash
            case name
            case size
        }
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

        private enum CodingKeys: String, CodingKey {
            case effectiveAmount = "effective_amount"
        }
    }

    static func == (lhs: Claim, rhs: Claim) -> Bool {
        return lhs.claimId == rhs.claimId
    }

    func hash(into hasher: inout Hasher) {
        claimId.hash(into: &hasher)
    }

    var outpoint: Outpoint? {
        if let txid = txid, let nout = nout {
            return Outpoint(txid: txid, index: nout)
        } else {
            return nil
        }
    }

    var titleOrName: String? {
        if let value, let title = value.title {
            return title
        }
        return name
    }
}
