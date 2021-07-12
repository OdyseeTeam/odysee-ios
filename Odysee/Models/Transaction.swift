//
//  swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 03/12/2020.
//

import Foundation

struct Transaction: Decodable, Hashable {
    var confirmations: Int?
    var date: String?
    var fee: String?
    var timestamp: Int64?
    var txid: String?
    var value: String?
    
    var abandonInfo: [TransactionInfo]?
    var claimInfo: [TransactionInfo]?
    var purchaseInfo: [TransactionInfo]?
    var supportInfo: [TransactionInfo]?
    var updateInfo: [TransactionInfo]?
    
    var description: String {
        if let abandonInfo = abandonInfo {
            if abandonInfo.count > 0 {
                if abandonInfo.count == 1 {
                    return String.localized(abandonInfo[0].balanceDelta! == abandonInfo[0].amount! ? "Unlock" : "Abandon")
                } else {
                    return String.localized("Unlock")
                }
            }
        }
        if let claimInfo = claimInfo {
            if claimInfo.count > 0 {
                return String.localized(claimInfo[0].claimName!.starts(with: "@") ? "Channel" : "Publish")
            }
        }
        if let updateInfo = updateInfo {
            if updateInfo.count > 0 {
                return String.localized(updateInfo[0].claimName!.starts(with: "@") ? "Channel Update" : "Publish Update")
            }
        }
        if let supportInfo = supportInfo {
            if supportInfo.count > 0 {
                return String.localized(supportInfo[0].isTip! ? "Tip" : "Support")
            }
        }
        
        return String.localized(value!.starts(with: "-") || (fee != nil && fee!.starts(with: "-")) ? "Spend" : "Receive")
    }
    
    var claim: Claim? {
        if let claimInfo = claimInfo {
            if claimInfo.count > 0 {
                let result = Claim()
                result.claimId = claimInfo[0].claimId
                result.name = claimInfo[0].claimName
                return result
            }
        }
        
        if let updateInfo = claimInfo {
            if updateInfo.count > 0 {
                let result = Claim()
                result.claimId = updateInfo[0].claimId
                result.name = updateInfo[0].claimName
                return result
            }
        }
        if let supportInfo = supportInfo {
            if supportInfo.count > 0 {
                let result = Claim()
                result.claimId = supportInfo[0].claimId
                result.name = supportInfo[0].claimName
                return result
            }
        }
        
        return nil
    }
    
    var actualValue: String? {
        return value
    }
    
    
    private enum CodingKeys: String, CodingKey {
        case confirmations, date, fee, timestamp, txid, value, abandonInfo = "abandon_info", claimInfo = "claim_info", purchaseInfo = "purchase_info", supportInfo = "support_info", updateInfo = "update_info"
    }

    struct TransactionInfo: Decodable {
        var address: String?
        var balanceDelta: String?
        var amount: String?
        var claimId: String?
        var claimName: String?
        var isTip: Bool?
        var nout: Int?
        
        private enum CodingKeys: String, CodingKey {
            case address, balanceDelta = "balance_delta", amount, claimId = "claim_id", claimName = "claim_name", isTip = "is_tip", nout = "nout"
        }
    }
    
    func hash(into hasher: inout Hasher) {
        txid?.hash(into: &hasher)
    }
    static func ==(lhs: Transaction, rhs: Transaction) -> Bool {
        return lhs.txid == rhs.txid
    }
}

struct Outpoint: Hashable {
    var txid: String
    var index: Int

    static func parse(str: String) -> Outpoint? {
        let substrs = str.split(separator: ":")
        guard substrs.count == 2, let index = Int(substrs[1]) else {
            return nil
        }
        return Outpoint(txid: String(substrs[0]), index: index)
    }
}
