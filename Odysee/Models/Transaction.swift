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
        if let abandonInfo = abandonInfo, abandonInfo.count > 0 {
            return String.localized(
                abandonInfo.count > 1 || abandonInfo[0].balanceDelta == abandonInfo[0].amount ? "Unlock" : "Abandon"
            )
        }
        if let claimInfo, claimInfo.count > 0 {
            return String.localized(
                claimInfo[0].claimName?.starts(with: "@") ?? false ? "Channel" : "Publish"
            )
        }
        if let updateInfo, updateInfo.count > 0 {
            return String.localized(
                updateInfo[0].claimName?.starts(with: "@") ?? false ? "Channel Update" : "Publish Update"
            )
        }
        if let supportInfo, supportInfo.count > 0 {
            return String.localized(supportInfo[0].isTip ?? false ? "Tip" : "Support")
        }

        return if let value, let fee, value.starts(with: "-") || fee.starts(with: "-") {
            String.localized("Spend")
        } else {
            String.localized("Receive")
        }
    }

    var claim: Claim? {
        if let claimInfo = claimInfo {
            if claimInfo.count > 0 {
                return Claim(
                    claimId: claimInfo[0].claimId,
                    name: claimInfo[0].claimName
                )
            }
        }

        if let updateInfo = claimInfo {
            if updateInfo.count > 0 {
                return Claim(
                    claimId: updateInfo[0].claimId,
                    name: updateInfo[0].claimName
                )
            }
        }
        if let supportInfo = supportInfo {
            if supportInfo.count > 0 {
                return Claim(
                    claimId: supportInfo[0].claimId,
                    name: supportInfo[0].claimName
                )
            }
        }

        return nil
    }

    var actualValue: String? {
        return value
    }

    private enum CodingKeys: String, CodingKey {
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

    struct TransactionInfo: Decodable {
        var address: String?
        var balanceDelta: String?
        var amount: String?
        var claimId: String?
        var claimName: String?
        var isTip: Bool?
        var nout: Int?

        private enum CodingKeys: String, CodingKey {
            case address
            case balanceDelta = "balance_delta"
            case amount
            case claimId = "claim_id"
            case claimName = "claim_name"
            case isTip = "is_tip"
            case nout
        }
    }

    func hash(into hasher: inout Hasher) {
        txid?.hash(into: &hasher)
    }

    static func == (lhs: Transaction, rhs: Transaction) -> Bool {
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
