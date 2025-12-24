//
//  AccountAPIResult.swift
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
