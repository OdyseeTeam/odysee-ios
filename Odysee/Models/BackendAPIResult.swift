//
//  BackendAPIResult.swift
//  Odysee
//
//  Created by Keith Toh on 18/12/2025.
//

import Foundation

typealias SyncHashResult = String

struct SyncApplyResult: Decodable {
    var hash: String
    var data: String
}

struct SharedPreferenceGetResult: Decodable {
    var shared: SharedPreference
}
