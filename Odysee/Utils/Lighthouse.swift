//
//  Lighthouse.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 12/11/2020.
//

import Foundation

final class Lighthouse {
    static let connectionString = "https://lighthouse.odysee.tv"

    static var relatedContentCache: [String: Any] = [:]

    static let keywordsForEmptyResults = [
        "corona",
        "coronavirus",
        "corona virus",
        "sars-cov-2",
        "sars cov 2",
        "sarscov2",
        "sars",
        "covid",
        "covid-19",
        "covid19",
        "covid 19",
    ] + Constants.NotTags

    static func containsFilteredKeyword(_ query: String) -> Bool {
        for keyword in keywordsForEmptyResults {
            let pattern = String(format: "\\b%@\\b", NSRegularExpression.escapedPattern(for: keyword))
            let trimmedQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedQuery
                .range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil || trimmedQuery == keyword
            {
                return true
            }
        }
        return false
    }

    static func search(
        rawQuery: String,
        size: Int,
        from: Int,
        relatedTo: String?,
        claimType: ClaimType? = nil,
        mediaTypes: [MediaType]? = nil,
        timeFilter: TimeFilter? = nil,
        sortBy: SortBy? = nil,
        completion: @escaping ([[String: Any]]?, Error?) -> Void
    ) {
        if !(relatedTo ?? "").isBlank {
            if let respData = relatedContentCache[String(format: "%@:%@", relatedTo!, rawQuery)] {
                completion(respData as? [[String: Any]], nil)
                return
            }
        }

        for keyword in keywordsForEmptyResults {
            let pattern = String(format: "\\b%@\\b", NSRegularExpression.escapedPattern(for: keyword))
            let trimmedQuery = rawQuery.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedQuery
                .range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil || trimmedQuery == keyword
            {
                completion([], nil)
                return
            }
            if relatedTo != nil, relatedTo!.contains(keyword) || relatedTo == keyword {
                completion([], nil)
                return
            }
        }

        var queryItems: [URLQueryItem] = []
        queryItems.append(URLQueryItem(name: "s", value: rawQuery))
        queryItems.append(URLQueryItem(name: "size", value: String(size)))
        queryItems.append(URLQueryItem(name: "from", value: String(from)))
        queryItems.append(URLQueryItem(name: "nsfw", value: "false"))
        queryItems.append(URLQueryItem(name: "free_only", value: "true"))
        queryItems.append(URLQueryItem(name: "filters", value: "ios"))
        if !(relatedTo ?? "").isBlank {
            queryItems.append(URLQueryItem(name: "related_to", value: String(relatedTo!)))
        }
        if let claimType = claimType {
            queryItems.append(URLQueryItem(name: "claimType", value: claimType.rawValue))

            if claimType == .stream {
                queryItems.append(URLQueryItem(
                    name: "mediaType",
                    value: mediaTypes?.map(\.rawValue).joined(separator: ",")
                ))
            }
        }
        if let timeFilter = timeFilter {
            queryItems.append(URLQueryItem(name: "time_filter", value: timeFilter.rawValue))
        }
        if let sortBy = sortBy {
            queryItems.append(URLQueryItem(name: "sort_by", value: sortBy.rawValue))
        }

        var urlComponents = URLComponents(string: String(format: "%@/search", connectionString))
        urlComponents?.queryItems = queryItems
        let url = urlComponents?.url

        let session = URLSession.shared
        var req = URLRequest(url: url!)
        req.httpMethod = "GET"

        let task = session.dataTask(with: req, completionHandler: { data, response, error in
            guard let data = data, error == nil else {
                // handle error
                completion([], error)
                return
            }
            do {
                var respCode = 0
                if let httpResponse = response as? HTTPURLResponse {
                    respCode = httpResponse.statusCode
                }
                let respData = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]]
                if respCode == 200 {
                    if !(relatedTo ?? "").isBlank {
                        relatedContentCache[String(format: "%@:%@", relatedTo!, rawQuery)] = respData
                    }
                    completion(respData, nil)
                } else {
                    completion([], nil)
                }
            } catch {
                completion([], error)
            }
        })
        task.resume()
    }

    enum MediaType: String {
        case video
        case audio
        case image
        case text
    }

    enum TimeFilter: String {
        case today
        case thisweek
        case thismonth
        case thisyear
    }

    enum SortBy: String {
        case ascending = "^release_time"
        case descending = "release_time"
    }
}
