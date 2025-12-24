//
//  LbryioAPIParams.swift
//  Odysee
//
//  Created by Keith Toh on 24/12/2025.
//

import Foundation

struct UserNewParams: Encodable, LbryioMethodParams {
    let language = "en"
    var appId: String

    enum CodingKeys: String, CodingKey {
        case language
        case appId = "app_id"
    }
}

struct SyncGetParams: Encodable, LbryioMethodParams {
    var hash: String
}
