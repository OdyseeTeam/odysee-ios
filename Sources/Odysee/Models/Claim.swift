//
//  Claim.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 02/11/2020.
//

import Foundation

public enum ClaimType: String, Codable {
    case channel
    case stream
    case repost
    case collection
}

public enum StreamType: String, Codable {
    case audio
    case binary
    case document
    case image
    case model
    case video
}

public class Claim: Decodable {
    
    public var address: String?
    public var amount: String?
    public var canonicalUrl: String?
    public var claimId: String?
    public var claimOp: String?
    public var confirmations: Int?
    public var height: Int?
    public var isChannelSignatureValid: Bool?
    public var meta: Meta?
    public var name: String?
    public var normalizedName: String?
    public var nout: Int?
    public var permanentUrl: String?
    public var shortUrl: String?
    public var signingChannel: Claim?
    public var repostedClaim: Claim?
    public var timestamp: Int64?
    public var txid: String?
    public var type: String?
    public var value: Metadata?
    public var valueType: ClaimType?
    public var selected: Bool = false
    public var featured: Bool = false
    
    public init(address: String? = nil, amount: String? = nil, canonicalUrl: String? = nil, claimId: String? = nil, claimOp: String? = nil, confirmations: Int? = nil, height: Int? = nil, isChannelSignatureValid: Bool? = nil, meta: Meta? = nil, name: String? = nil, normalizedName: String? = nil, nout: Int? = nil, permanentUrl: String? = nil, shortUrl: String? = nil, signingChannel: Claim? = nil, repostedClaim: Claim? = nil, timestamp: Int64? = nil, txid: String? = nil, type: String? = nil, value: Metadata? = nil, valueType: ClaimType? = nil) {
        self.address = address
        self.amount = amount
        self.canonicalUrl = canonicalUrl
        self.claimId = claimId
        self.claimOp = claimOp
        self.confirmations = confirmations
        self.height = height
        self.isChannelSignatureValid = isChannelSignatureValid
        self.meta = meta
        self.name = name
        self.normalizedName = normalizedName
        self.nout = nout
        self.permanentUrl = permanentUrl
        self.shortUrl = shortUrl
        self.signingChannel = signingChannel
        self.repostedClaim = repostedClaim
        self.timestamp = timestamp
        self.txid = txid
        self.type = type
        self.value = value
        self.valueType = valueType
    }

    enum CodingKeys: String, CodingKey {
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
}

public extension Claim {
    
    struct Metadata: Decodable, Equatable {
        public var title: String?
        public var description: String?
        public var thumbnail: Resource?
        public var languages: [String]?
        public var tags: [String]?
        public var locations: [Location]?

        // channel
        public var publicKey: String?
        public var publicKeyId: String?
        public var cover: Resource?
        public var email: String?
        public var websiteUrl: String?
        public var featured: [String]?

        // stream
        public var license: String?
        public var licenseUrl: String?
        public var releaseTime: String?
        public var author: String?
        public var fee: Fee?
        public var streamType: String?
        public var source: Source?
        public var video: StreamInfo?
        public var audio: StreamInfo?
        public var image: StreamInfo?
        public var software: StreamInfo?

        // collection
        public var claims: [String]?

        enum CodingKeys: String, CodingKey {
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

    struct Source: Decodable, Hashable {
        
        public var sdHash: String?
        public var mediaType: String?
        public var hash: String?
        public var name: String?
        public var size: String?

        enum CodingKeys: String, CodingKey {
            case sdHash = "sd_hash"
            case mediaType = "media_type"
            case hash
            case name
            case size
        }
    }

    struct Fee: Decodable, Hashable {
        
        public var amount: String?
        public var currency: String?
        public var address: String?
    }

    struct Location: Decodable, Hashable {
        
        public var country: String?
    }

    struct Resource: Decodable, Hashable {
        
        // TODO: make this `URL?`
        public var url: String?
    }

    struct StreamInfo: Decodable, Hashable {
        
        public var duration: Int64?
        public var height: Int64?
        public var width: Int64?
        public var os: String?
    }

    struct Meta: Decodable, Hashable {
        
        public var effectiveAmount: String?

        enum CodingKeys: String, CodingKey {
            case effectiveAmount = "effective_amount"
        }
    }
}
