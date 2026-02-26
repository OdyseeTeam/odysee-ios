//
//  BackendAPIResult.swift
//  Odysee
//
//  Created by Keith Toh on 18/12/2025.
//

import Foundation

struct AddressListResult: Decodable {
    var items: [AddressListResultElement]
}

struct AddressListResultElement: Decodable {
    var address: String
    var publicKey: String

    enum CodingKeys: String, CodingKey {
        case address
        case publicKey = "pubkey"
    }
}

struct ChannelSignResult: Decodable {
    var signature: String
    var signingTs: String

    enum CodingKeys: String, CodingKey {
        case signature
        case signingTs = "signing_ts"
    }
}

typealias SyncHashResult = String

struct SyncApplyResult: Decodable {
    var hash: String
    var data: String
}

struct SharedPreferenceGetResult: Decodable {
    var shared: SharedPreference
}
