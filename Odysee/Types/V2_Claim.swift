//
//  V2_Claim.swift
//  Odysee
//
//  Created by Keith on 29/09/2026.
//

import Foundation
import Tagged

/// All fields from Protobuf are [Implicitly Present](https://protobuf.dev/design-decisions/implicit-presence/#what) and need not be Optional
// TODO: Txo has all these same fields except for claim-specific
struct V2_Claim: Decodable {
    /// `Output` base fields
    ///
    /// <https://github.com/OdyseeTeam/lbry-sdk/blob/7080e2df69eb0312bb3e24e0c26939aaaeca0aef/lbry/extras/daemon/json_response_encoder.py#L168-L176>
    var txid: String
    var nout: Int
    var height: Int
    @LbcAmount var amount
    var address: String
    var confirmations: Int
    var timestamp: TimeInterval // FIXME: Time

    /// Optional fields from [`Output`](https://github.com/OdyseeTeam/lbry-sdk/blob/7080e2df69eb0312bb3e24e0c26939aaaeca0aef/lbry/wallet/transaction.py#L209)
    ///
    /// <https://github.com/OdyseeTeam/lbry-sdk/blob/7080e2df69eb0312bb3e24e0c26939aaaeca0aef/lbry/extras/daemon/json_response_encoder.py#L177-L190>
    var isSpent: Bool?
    var isMyOutput: Bool?
    var isMyInput: Bool?
    @OptionalLbcAmount var sentSupports
    @OptionalLbcAmount var sentTips
    @OptionalLbcAmount var receivedTips
    var isInternalTransfer: Bool?

    /// <https://github.com/OdyseeTeam/lbry-sdk/blob/7080e2df69eb0312bb3e24e0c26939aaaeca0aef/lbry/extras/daemon/json_response_encoder.py#L192-L208>
    ///
    /// Only ["claim involved"](https://github.com/OdyseeTeam/lbry-sdk/blob/7080e2df69eb0312bb3e24e0c26939aaaeca0aef/lbry/wallet/script.py#L592-L593) `type`s are supported
    var type: OutputType
    /// Present when `type` is `.claim`
    ///
    /// <https://github.com/OdyseeTeam/lbry-sdk/blob/7080e2df69eb0312bb3e24e0c26939aaaeca0aef/lbry/extras/daemon/json_response_encoder.py#L192-L197>
    var claimOp: ClaimOp?
    // FIXME: Purchased claim nested

    /// Claim stake `Output` base fields
    ///
    /// <https://github.com/OdyseeTeam/lbry-sdk/blob/7080e2df69eb0312bb3e24e0c26939aaaeca0aef/lbry/extras/daemon/json_response_encoder.py#L211-L217>
    var name: String
    var normalizedName: String
    var claimId: String
    var permanentUrl: String // FIXME: Urls String or LbryUrl?
    var meta: Meta
    /// <https://github.com/OdyseeTeam/lbry-sdk/blob/7080e2df69eb0312bb3e24e0c26939aaaeca0aef/lbry/extras/daemon/json_response_encoder.py#L218-L219>
    ///
    /// Shouldn't be `nil` due to being implicitly present in `meta` and then moved here,
    /// but this is optional to encourage using `permanentUrl` instead.
    var shortUrl: String?
    /// <https://github.com/OdyseeTeam/lbry-sdk/blob/7080e2df69eb0312bb3e24e0c26939aaaeca0aef/lbry/extras/daemon/json_response_encoder.py#L220-L221>
    ///
    /// Shouldn't be `nil` due to being implicitly present in `meta` and then moved here,
    /// but this is optional to encourage using `permanentUrl` instead.
    var canonicalUrl: String?
    /// Present on `collection_list` call with `resolve_claims` set
    ///
    /// <https://github.com/OdyseeTeam/lbry-sdk/blob/7080e2df69eb0312bb3e24e0c26939aaaeca0aef/lbry/wallet/ledger.py#L1252-L1254>
    var claims: [V2_Claim]?
    /// <https://github.com/OdyseeTeam/lbry-sdk/blob/7080e2df69eb0312bb3e24e0c26939aaaeca0aef/lbry/extras/daemon/json_response_encoder.py#L224-L225>
    @ClaimBox var repostedClaim

    // FIXME: https://github.com/OdyseeTeam/lbry-sdk/blob/7080e2df69eb0312bb3e24e0c26939aaaeca0aef/lbry/extras/daemon/json_response_encoder.py#L226-L245

    // MARK: - Tagged (Phantom Types)

    // FIXME: Implement

    // MARK: - Supporting Types

    @propertyWrapper
    struct LbcAmount: Decodable {
        var wrappedValue: WrappedValue

        typealias WrappedValue = Tagged<LbcAmount, Double>

        init(wrappedValue: WrappedValue = 0) {
            self.wrappedValue = wrappedValue
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.singleValueContainer()

            guard let value = try WrappedValue(container.decode(String.self)) else {
                throw DecodingError.typeMismatch(WrappedValue.RawValue.self, .init(
                    codingPath: decoder.codingPath, debugDescription: "Couldn't parse Double"
                ))
            }

            wrappedValue = value
        }
    }

    @propertyWrapper
    struct OptionalLbcAmount: Decodable {
        var wrappedValue: WrappedValue?

        typealias WrappedValue = Tagged<LbcAmount, Double>

        init(wrappedValue: WrappedValue? = nil) {
            self.wrappedValue = wrappedValue
        }

        enum CodingKeys: CodingKey {
            case wrappedValue
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.singleValueContainer()

            if let value = try WrappedValue.RawValue(container.decode(String.self)) {
                wrappedValue = WrappedValue(value)
            }
        }
    }

    enum OutputType: String, Decodable {
        case claim
        case support
        case purchase
    }

    enum ClaimOp: String, Decodable {
        case create
        case update
    }

    /// <https://github.com/OdyseeTeam/lbry-sdk/blob/7080e2df69eb0312bb3e24e0c26939aaaeca0aef/lbry/schema/result.py#L132-L158>
    struct Meta: Decodable {
        var reposted: Int
        var isControlling: Bool
        var takeOverHeight: Int
        var creationHeight: Int
        var activationHeight: Int
        var expirationHeight: Int
        @LbcAmount var effectiveAmount
        @LbcAmount var supportAmount
        /// <https://github.com/OdyseeTeam/lbry-sdk/blob/7080e2df69eb0312bb3e24e0c26939aaaeca0aef/lbry/schema/result.py#L155-L156>
        ///
        /// This field is implicitly present in Protobuf, but the sdk only passes it along for channels
        var claimsInChannel: Int?
        /// <https://github.com/OdyseeTeam/lbry-sdk/blob/7080e2df69eb0312bb3e24e0c26939aaaeca0aef/lbry/extras/daemon/json_response_encoder.py#L253-L254>
        var creationTimestamp: Int? // FIXME: Time
    }

    @propertyWrapper
    final class ClaimBox: Decodable {
        let wrappedValue: V2_Claim?

        init(from decoder: Decoder) throws {
            wrappedValue = try V2_Claim(from: decoder)
        }

        init(wrappedValue: V2_Claim? = nil) {
            self.wrappedValue = wrappedValue
        }
    }
}

// MARK: - Decoding Optional Property Wrappers

// FIXME: Test with present but null
extension KeyedDecodingContainer {
    /// Handle decoding property wrapper with optional wrapped value
    /// <https://forums.swift.org/t/using-property-wrappers-with-codable/29804/12>
    func decode(_ type: V2_Claim.OptionalLbcAmount.Type, forKey key: Self.Key) throws -> V2_Claim.OptionalLbcAmount {
        try decodeIfPresent(type, forKey: key) ?? .init()
    }
}

extension KeyedDecodingContainer {
    /// Handle decoding property wrapper with optional wrapped value
    /// <https://forums.swift.org/t/using-property-wrappers-with-codable/29804/12>
    func decode(_ type: V2_Claim.ClaimBox.Type, forKey key: Self.Key) throws -> V2_Claim.ClaimBox {
        try decodeIfPresent(type, forKey: key) ?? .init()
    }
}

// MARK: - Protocol Conformances

extension V2_Claim: Identifiable {
    // FIXME: Tagged
    var id: String {
        claimId
    }
}
