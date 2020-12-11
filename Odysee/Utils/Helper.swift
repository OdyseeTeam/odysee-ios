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
    
    static let sortByItemNames = ["Trending content", "New content", "Top content"]
    static let contentFromItemNames = ["Past 24 hours", "Past week", "Past month", "Past year", "All time"]
    static let sortByItemValues = [
        ["trending_group", "trending_mixed"], ["release_time"], ["effective_amount"]
    ];
    
    static let sdkAmountFormatter = NumberFormatter()
    static let currencyFormatter = NumberFormatter()
    static let currencyFormatter4 = NumberFormatter()
    static func initFormatters() {
        currencyFormatter.roundingMode = .down
        currencyFormatter.minimumFractionDigits = 2
        currencyFormatter.maximumFractionDigits = 2
        currencyFormatter.usesGroupingSeparator = true
        currencyFormatter.numberStyle = .decimal
        currencyFormatter.locale = Locale.current
        
        currencyFormatter4.roundingMode = .up
        currencyFormatter4.minimumFractionDigits = 4
        currencyFormatter4.maximumFractionDigits = 4
        currencyFormatter4.usesGroupingSeparator = true
        currencyFormatter4.numberStyle = .decimal
        currencyFormatter4.locale = Locale.current
        
        sdkAmountFormatter.minimumFractionDigits = 2
        sdkAmountFormatter.maximumFractionDigits = 8
        sdkAmountFormatter.usesGroupingSeparator = false
        sdkAmountFormatter.numberStyle = .decimal
        sdkAmountFormatter.locale = Locale.init(identifier: "en_US")
    }

    static func isAddressValid(address: String?) -> Bool {
        if (address ?? "").isBlank {
            return false
        }
        // TODO: Figure out why regex is broken
        /*
        if LbryUri.regexAddress.firstMatch(in: address!, options: [], range: NSRange(address!.startIndex..., in:address!)) == nil {
            return false
        }*/
        if !address!.starts(with: "b") {
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
    
    static func buildReleaseTime(contentFrom: String?) -> String? {
        if (contentFrom == contentFromItemNames[4]) {
            return nil
        }
        
        var time = Int64(Date().timeIntervalSince1970)
        if (contentFrom == contentFromItemNames[0]) {
            time = time - (60 * 60 * 24)
        } else if (contentFrom == contentFromItemNames[1]) {
            time = time - (60 * 60 * 24 * 7)
        } else if (contentFrom == contentFromItemNames[2]) {
            time = time - (60 * 60 * 24 * 30) // conservative month estimate?
        } else if (contentFrom == contentFromItemNames[3]) {
            time = time - (60 * 60 * 24 * 365)
        }
        
        return String(format: ">%d", time)
    }
    
    static func buildPickerActionSheet(title: String, dataSource: UIPickerViewDataSource, delegate: UIPickerViewDelegate, parent: UIViewController, handler: ((UIAlertAction) -> Void)? = nil) -> (UIPickerView, UIAlertController) {
        let pickerFrame = CGRect(x: 0, y: 0, width: parent.view.frame.width, height: 160)
        let picker = UIPickerView(frame: pickerFrame)
        picker.dataSource = dataSource
        picker.delegate = delegate
        
        let alert = UIAlertController(title: title, message: "", preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: String.localized("Done"), style: .default, handler: handler))
        
        let vc = UIViewController()
        vc.preferredContentSize = CGSize(width: parent.view.frame.width, height: 160)
        vc.view.addSubview(picker)
        alert.setValue(vc, forKey: "contentViewController")
        
        return (picker, alert)
    }

    static func shortCurrencyFormat(value: Decimal?) -> String {
        let formatter = NumberFormatter()
        formatter.usesGroupingSeparator = true
        formatter.roundingMode = .down
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 2
        
        if (value! > 1000000000) {
            return String(format: "%@B", formatter.string(for: (value! / 1000000000) as NSDecimalNumber)!)
        }
        if (value! > 1000000) {
            return String(format: "%@M", formatter.string(for: (value! / 1000000) as NSDecimalNumber)!)
        }
        if (value! > 1000) {
            return String(format: "%@K", formatter.string(for: (value! / 1000) as NSDecimalNumber)!)
        }
        
        return formatter.string(for: value! as NSDecimalNumber)!
    }
}
