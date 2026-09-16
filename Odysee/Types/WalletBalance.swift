//
//  WalletBalance.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 01/12/2020.
//

import Foundation

struct WalletBalance: Decodable {
    static let zero = WalletBalance()

    var available: Decimal
    var reserved: Decimal
    var total: Decimal
    var claims: Decimal
    var supports: Decimal
    var tips: Decimal

    enum CodingKeys: String, CodingKey {
        case available
        case reserved
        case total
        case reservedSubtotals

        case claims
        case supports
        case tips
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        available = try container.decodeDecimalString(forKey: .available)
        reserved = try container.decodeDecimalString(forKey: .reserved)
        total = try container.decodeDecimalString(forKey: .total)

        let subtotalsContainer = try container.nestedContainer(keyedBy: CodingKeys.self, forKey: .reservedSubtotals)
        claims = try subtotalsContainer.decodeDecimalString(forKey: .claims)
        supports = try subtotalsContainer.decodeDecimalString(forKey: .supports)
        tips = try subtotalsContainer.decodeDecimalString(forKey: .tips)
    }

    /// Initializes a zero balance
    private init() {
        available = 0
        reserved = 0
        total = 0
        claims = 0
        supports = 0
        tips = 0
    }
}
