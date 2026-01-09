//
//  LbryioAPIParams.swift
//  Odysee
//
//  Created by Keith Toh on 24/12/2025.
//

import Foundation

struct SyncGetParams: Encodable, LbryioMethodParams {
    var hash: String
}
