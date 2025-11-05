//
//  WalletBalance.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 01/12/2020.
//

import Foundation

public struct WalletBalance {
    public var available: Decimal?
    public var reserved: Decimal?
    public var claims: Decimal?
    public var supports: Decimal?
    public var tips: Decimal?
    public var total: Decimal?
}
