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

struct UserExistsParams: Encodable, AccountMethodParams {
    var email: String
}

struct UserSignInUpParams: Encodable, AccountMethodParams {
    var email: String
    var password: String
}

struct UserEmailResendTokenParams: Encodable, AccountMethodParams {
    var email: String
    let only_if_expired = true
}

struct SyncGetParams: Encodable, AccountMethodParams {
    var hash: String
}

struct SyncSetParams: Encodable, AccountMethodParams {
    var oldHash: String
    var newHash: String
    var data: String

    enum CodingKeys: String, CodingKey {
        case oldHash = "old_hash"
        case newHash = "new_hash"
        case data
    }
}
