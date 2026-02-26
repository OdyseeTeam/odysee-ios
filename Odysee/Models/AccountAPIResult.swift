//
//  AccountAPIResult.swift
//  Odysee
//
//  Created by Keith Toh on 24/12/2025.
//

import Foundation

struct UserNewResult: Decodable {
    var authToken: String

    enum CodingKeys: String, CodingKey {
        case authToken = "auth_token"
    }
}

struct UserExistsResult: Decodable {
    var hasPassword: Bool

    enum CodingKeys: String, CodingKey {
        case hasPassword = "has_password"
    }
}

struct SyncGetResult: Decodable {
    var changed: Bool
    var hash: String?
    var data: String?
}

struct SyncSetResult: Decodable {
    var changed: Bool
    var hash: String?
}

typealias YtTransferResult = [YtTransferResultElement]

struct YtTransferResultElement: Decodable {
    var channel: AccountYoutubeChannel?
    var totalPublishedVideos: Int
    var totalTransferred: Int
    var changed: Bool

    enum CodingKeys: String, CodingKey {
        case channel
        case totalPublishedVideos = "total_published_videos"
        case totalTransferred = "total_transferred"
        case changed
    }
}
