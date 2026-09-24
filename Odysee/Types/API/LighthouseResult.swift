//
//  LighthouseResult.swift
//  Odysee
//
//  Created by Keith on 28/09/2026.
//

import Foundation

typealias SearchResult = [SearchResultItem]

struct SearchResultItem: Decodable {
    var name: String
    var claimId: String
}
