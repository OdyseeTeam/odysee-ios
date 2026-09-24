//
//  LighthouseParams.swift
//  Odysee
//
//  Created by Keith on 28/09/2026.
//

import Foundation

struct SearchParams: Encodable, LighthouseMethodParams {
    var query: String
    var size: Int
    var from: Int
    /// Claim ID
    var relatedTo: String?
    var claimType: ClaimType?
    var mediaTypes: [MediaType]?
    var timeFilter: TimeFilter?
    var sortBy: SortBy?
    let nsfw = false
    let freeOnly = true
    let filters = "ios"

    enum CodingKeys: String, CodingKey {
        case query = "s"
        case size
        case from
        case relatedTo = "related_to"
        case claimType
        case mediaTypes = "mediaType"
        case timeFilter = "time_filter"
        case sortBy = "sort_by"
        case nsfw
        case freeOnly = "free_only"
        case filters
    }

    enum MediaType: String, Encodable {
        case video
        case audio
        case image
        case text
    }

    enum TimeFilter: String, Encodable {
        case today
        case thisweek
        case thismonth
        case thisyear
    }

    enum SortBy: String, Encodable {
        case ascending = "^release_time"
        case descending = "release_time"
    }
}
