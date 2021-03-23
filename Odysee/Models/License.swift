//
//  License.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 22/03/2021.
//

import Foundation

struct License {
    var name: String?
    var url: String?
    var localizedName: String {
        return String.localized(name ?? "")
    }
}
