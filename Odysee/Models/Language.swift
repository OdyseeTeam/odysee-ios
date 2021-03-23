//
//  Language.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 22/03/2021.
//

import Foundation

struct Language {
    var code: String?
    var name: String?
    var localizedName: String {
        return String.localized(name ?? "")
    }
}
