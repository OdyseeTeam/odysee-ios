//
//  WalletSync.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 04/12/2020.
//

import Foundation

public struct WalletSync: Decodable {
    public var hash: String?
    public var data: String?
    public var changed: Bool?
    
    public init(hash: String? = nil, data: String? = nil, changed: Bool? = nil) {
        self.hash = hash
        self.data = data
        self.changed = changed
    }
}
