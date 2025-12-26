//
//  LbryioAPIResult.swift
//  Odysee
//
//  Created by Keith Toh on 24/12/2025.
//

import Foundation

struct UserNewResult: Decodable {
    var authToken: String

    enum CodingKeys: String, CodingKey {
        case authToken = "auth_token"
    }
}

struct SyncGetResult: Decodable {
    var changed: Bool
    var hash: String?
    var data: String?
}
