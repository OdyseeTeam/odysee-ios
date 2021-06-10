//
//  Page.swift
//  Odysee
//
//  Created by Adlai Holler on 6/10/21.
//

import Foundation

struct Page<Item: Decodable>: Decodable {
    var pageSize: Int
    var items: [Item] {
        get { return _items ?? [] }
        set { _items = newValue }
    }
    
    // Server encodes [] as missing `items` key. Optional array is annoying. Workaround.
    private var _items: [Item]?
    
    private enum CodingKeys: String, CodingKey {
        case _items = "items", pageSize = "page_size"
    }
}
