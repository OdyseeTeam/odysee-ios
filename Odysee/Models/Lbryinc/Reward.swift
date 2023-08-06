//
//  Reward.swift
//  OdyseeApp
//
//  Created by Alsey Coleman Miller on 8/5/23.
//

import Foundation
import Odysee

extension Reward {
    
    var displayAmount: String {
        if shouldDisplayRange {
            return String(rewardRange!.split(separator: "-")[1])
        }
        if rewardAmount ?? 0 > 0 {
            return Helper.currencyFormatter.string(for: rewardAmount!)!
        }

        return "?"
    }

    var shouldDisplayRange: Bool {
        return !claimed && !(rewardRange ?? "").isBlank && rewardRange?.firstIndex(of: "-") != nil
    }

    var claimed: Bool {
        return !(transactionId ?? "").isBlank
    }
}
