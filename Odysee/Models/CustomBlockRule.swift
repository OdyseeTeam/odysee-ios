//
//  CustomBlockRule.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 15/03/2022.
//

import Foundation

enum CustomBlockContentType: String, Codable {
    case livestreams
    case videos
}

enum CustomBlockScope: String, Codable {
    case continent
    case country
    case special
}

struct CustomBlockRule {
    var type: CustomBlockContentType?
    var scope: CustomBlockScope?
    var reason: String?
    var trigger: String?
    var id: String?
    var message: String?
}
