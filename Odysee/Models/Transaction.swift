//
//  Transaction.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 03/12/2020.
//

import Foundation

struct Transaction: Decodable {
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
}

