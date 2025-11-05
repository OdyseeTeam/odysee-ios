//
//  Transaction.swift
//  OdyseeApp
//
//  Created by Alsey Coleman Miller on 8/5/23.
//

import Foundation
import Odysee

extension Transaction {

    var descriptionText: String {
        if let abandonInfo = abandonInfo {
            if abandonInfo.count > 0 {
                if abandonInfo.count == 1 {
                    return String
                        .localized(abandonInfo[0].balanceDelta! == abandonInfo[0].amount! ? "Unlock" : "Abandon")
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
                return String
                    .localized(updateInfo[0].claimName!.starts(with: "@") ? "Channel Update" : "Publish Update")
            }
        }
        if let supportInfo = supportInfo {
            if supportInfo.count > 0 {
                return String.localized(supportInfo[0].isTip! ? "Tip" : "Support")
            }
        }

        return String
            .localized(value!.starts(with: "-") || (fee != nil && fee!.starts(with: "-")) ? "Spend" : "Receive")
    }
    
    var actualValue: String? {
        return value
    }
}

extension Transaction: Hashable {
    
    public func hash(into hasher: inout Hasher) {
        txid?.hash(into: &hasher)
    }
}
