//
//  Helper.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 10/11/2020.
//

import Base58Swift
import Foundation
import UIKit

final class Helper {
    static let primaryColor: UIColor = UIColor.init(red: 229.0/255.0, green: 0, blue: 84.0/255.0, alpha: 1)
    static let lightPrimaryColor: UIColor = UIColor.init(red: 250.0/255.0, green: 97.0/255.0, blue: 101.0/255.0, alpha: 1)
    
    static let currencyFormatter = NumberFormatter()
    static func initCurrencyFormatter() {
        currencyFormatter.roundingMode = .down
        currencyFormatter.minimumFractionDigits = 2
        currencyFormatter.maximumFractionDigits = 2
        currencyFormatter.usesGroupingSeparator = true
        currencyFormatter.numberStyle = .decimal
        currencyFormatter.locale = Locale.current
    }

    static func isAddressValid(address: String?) -> Bool {
        if (address ?? "").isBlank {
            return false
        }
        if LbryUri.regexAddress.firstMatch(in: address!, options: [], range: NSRange(address!.startIndex..., in:address!)) == nil {
            return false
        }
        if Base58.base58CheckDecode(address!) == nil {
            return false
        }
        
        return true
    }
    
    static func describeTransaction(transaction: Transaction) -> String {
        if let abandonInfo = transaction.abandonInfo {
            if abandonInfo.count > 0 {
                if abandonInfo.count == 1 {
                    return String.localized(abandonInfo[0].balanceDelta! == abandonInfo[0].amount! ? "Unlock" : "Abandon")
                } else {
                    return String.localized("Unlock")
                }
            }
        }
        if let claimInfo = transaction.claimInfo {
            if claimInfo.count > 0 {
                return String.localized(claimInfo[0].claimName!.starts(with: "@") ? "Channel" : "Publish")
            }
        }
        if let supportInfo = transaction.supportInfo {
            if supportInfo.count > 0 {
                return String.localized(supportInfo[0].isTip! ? "Tip" : "Support")
            }
        }
        if let updateInfo = transaction.claimInfo {
            if updateInfo.count > 0 {
                return String.localized(updateInfo[0].claimName!.starts(with: "@") ? "Channel Update" : "Publish Update")
            }
        }
        
        return String.localized(transaction.value!.starts(with: "-") || (transaction.fee != nil && transaction.fee!.starts(with: "-")) ? "Spend" : "Receive")
    }
}
