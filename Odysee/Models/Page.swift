//
//  Page.swift
//  Odysee
//
//  Created by Adlai Holler on 6/10/21.
//

import Foundation

struct Page<Item: Decodable>: Decodable {
    var items: [Item]
    var isLastPage: Bool

    init(items: [Item], isLastPage: Bool) {
        self.items = items
        self.isLastPage = isLastPage
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        items = try container.decodeIfPresent([Item].self, forKey: .items) ?? []

        let page = try container.decodeIfPresent(Int.self, forKey: .page)
        let totalPages = try container.decodeIfPresent(Int.self, forKey: .totalPages)
        isLastPage = page == totalPages
    }

    private enum CodingKeys: String, CodingKey {
        case items
        case page
        case totalPages = "total_pages"
    }
}
