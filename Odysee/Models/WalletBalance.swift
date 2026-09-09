//
//  WalletBalance.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 01/12/2020.
//

import Foundation

@dynamicMemberLookup
struct WalletBalance: Decodable {
    var available: Decimal
    var reserved: Decimal
    var total: Decimal
    var reservedSubtotals: ReservedSubtotals

    enum CodingKeys: String, CodingKey {
        case available
        case reserved
        case total
        case reservedSubtotals = "reserved_subtotals"
    }

    subscript(dynamicMember keyPath: KeyPath<ReservedSubtotals, Decimal>) -> Decimal {
        reservedSubtotals[keyPath: keyPath]
    }

    struct ReservedSubtotals: Decodable {
        var claims: Decimal
        var supports: Decimal
        var tips: Decimal

        enum CodingKeys: CodingKey {
            case claims
            case supports
            case tips
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            claims = try container.decodeDecimalString(forKey: .claims)
            supports = try container.decodeDecimalString(forKey: .supports)
            tips = try container.decodeDecimalString(forKey: .tips)
        }
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        available = try container.decodeDecimalString(forKey: .available)
        reserved = try container.decodeDecimalString(forKey: .reserved)
        total = try container.decodeDecimalString(forKey: .total)
        reservedSubtotals = try container.decode(ReservedSubtotals.self, forKey: .reservedSubtotals)
    }
}
