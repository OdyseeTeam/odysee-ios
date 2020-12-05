//
//  WalletSync.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 04/12/2020.
//

import Foundation

struct WalletSync: Decodable {
    var hash: String?
    var data: String?
    var changed: Bool?
}
