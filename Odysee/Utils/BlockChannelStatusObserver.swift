//
//  BlockChannelStatusListener.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 18/07/2022.
//

import Foundation

protocol BlockChannelStatusObserver {
    func blockChannelStatusChanged(claimId: String, isBlocked: Bool)
}
