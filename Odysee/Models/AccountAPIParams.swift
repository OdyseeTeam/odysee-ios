//
//  AccountAPIParams.swift
//  Odysee
//
//  Created by Keith Toh on 24/12/2025.
//

import Foundation

struct UserNewParams: Encodable, AccountMethodParams {
    let language = "en"
    var appId: String

    enum CodingKeys: String, CodingKey {
        case language
        case appId = "app_id"
    }
}
