//
//  Claim.swift
//  OdyseeApp
//
//  Created by Alsey Coleman Miller on 8/5/23.
//

import Foundation
import Odysee

extension Claim {
    
    var outpoint: Outpoint? {
        if let txid = txid, let nout = nout {
            return Outpoint(txid: txid, index: nout)
        } else {
            return nil
        }
    }

    var titleOrName: String? {
        if let value = value, let title = value.title {
            return title
        }
        return name
    }
}

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

public struct Outpoint: Hashable {
    
    public var txid: String
    public var index: Int
    
    public init(txid: String, index: Int) {
        self.txid = txid
        self.index = index
    }

    public static func parse(_ str: String) -> Outpoint? {
        let substrs = str.split(separator: ":")
        guard substrs.count == 2, let index = Int(substrs[1]) else {
            return nil
        }
        return Outpoint(txid: String(substrs[0]), index: index)
    }
}
