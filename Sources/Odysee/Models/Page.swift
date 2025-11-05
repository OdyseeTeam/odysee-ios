//
//  Page.swift
//  Odysee
//
//  Created by Adlai Holler on 6/10/21.
//

import Foundation

public struct Page<Item: Decodable>: Decodable {
    
    public var pageSize: Int
    public var items: [Item]
    public var isLastPage: Bool
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        pageSize = try container.decode(Int.self, forKey: .pageSize)
        items = try container.decodeIfPresent([Item].self, forKey: .items) ?? []
        isLastPage = items.count < pageSize
    }

    enum CodingKeys: String, CodingKey {
        case items
        case pageSize = "page_size"
    }
}
