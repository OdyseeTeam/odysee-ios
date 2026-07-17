//
//  SharedPreference+Settings.swift
//  Odysee
//
//  Created by Keith on 15/07/2026.
//

import Foundation

// MARK: - Mutators and Predicates

extension SharedPreference {
    mutating func setDefaultChannelId(channelId: String) {
        defaultChannelId = channelId
    }
}
