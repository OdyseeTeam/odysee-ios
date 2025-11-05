//
//  swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 03/12/2020.
//

import Foundation

public struct Transaction: Decodable, Equatable {
    
    public var confirmations: Int?
    public var date: String?
    public var fee: String?
    public var timestamp: Int64?
    public var txid: String?
    public var value: String?
    
    public var abandonInfo: [TransactionInfo]?
    public var claimInfo: [TransactionInfo]?
    public var purchaseInfo: [TransactionInfo]?
    public var supportInfo: [TransactionInfo]?
    public var updateInfo: [TransactionInfo]?
    
    enum CodingKeys: String, CodingKey {
        case confirmations
        case date
        case fee
        case timestamp
        case txid
        case value
        case abandonInfo = "abandon_info"
        case claimInfo = "claim_info"
        case purchaseInfo = "purchase_info"
        case supportInfo = "support_info"
        case updateInfo = "update_info"
    }
}

public struct TransactionInfo: Decodable, Hashable {
    public var address: String?
    public var balanceDelta: String?
    public var amount: String?
    public var claimId: String?
    public var claimName: String?
    public var isTip: Bool?
    public var nout: Int?

    enum CodingKeys: String, CodingKey {
        case address
        case balanceDelta = "balance_delta"
        case amount
        case claimId = "claim_id"
        case claimName = "claim_name"
        case isTip = "is_tip"
        case nout
    }
}

public extension Transaction {
    
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
}
