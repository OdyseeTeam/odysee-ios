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

        if let page = try container.decodeIfPresent(Int.self, forKey: .page),
           let totalPages = try container.decodeIfPresent(Int.self, forKey: .totalPages)
        {
            isLastPage = page == totalPages
        } else if let hasMore = try container.decodeIfPresent(Bool.self, forKey: .hasMore) {
            isLastPage = !hasMore
        } else {
            isLastPage = false
        }
    }

    private enum CodingKeys: String, CodingKey {
        case items
        case page

        /// Backend API
        case totalPages = "total_pages"
        /// Account API `user/view_history`
        case hasMore = "has_more"
    }
}
