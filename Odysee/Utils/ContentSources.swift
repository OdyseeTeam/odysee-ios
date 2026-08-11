//
//  ContentSources.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 04/11/2020.
//

import Foundation

@MainActor
enum ContentSources {
    static let languageCodeEN = "en"
    static let regionCodeUS = "US"
    static let regionCodeBR = "BR" // special check for pt-BR

    static let defaultsKey = "ContentSourcesCache"
    // swift-format-ignore
    // Initialized once with static value
    static let endpoint = URL(string: "https://odysee.com/$/api/content/v2/get")!

    static let discoverCategory = "EXPLORABLE_CHANNEL"

    static let placeholderDiscoverCategory = Category(
        key: HomeViewController.categoryKeyDiscover,
        sortOrder: 1,
        name: HomeViewController.categoryKeyDiscover,
        label: "Discover",
        channelLimit: 1,
        channelIds: [],
        excludedChannelIds: []
    )

    static var DynamicContentCategories: [Category] = [placeholderDiscoverCategory] {
        didSet {
            if DynamicContentCategories.count == 0 {
                DynamicContentCategories = [placeholderDiscoverCategory]
            }
        }
    }

    static func loadCategories() async throws {
        let defaults = UserDefaults.standard

        if let csCacheString = defaults.string(forKey: defaultsKey),
           let csCache = try? JSONDecoder().decode(ContentSourceCache.self, from: csCacheString.data),
           let diff = Calendar.current.dateComponents([.hour], from: csCache.lastUpdated, to: Date()).hour,
           diff < 24
        {
            ContentSources.DynamicContentCategories = csCache.categories
            return
        }

        try await loadRemoteCategories()
    }

    private struct ErrorResponse: Decodable {
        var error: String?
    }

    private struct ContentSourcesResponse: Decodable {
        var data: [String: Homepage]

        struct Homepage: Decodable {
            var discoverNewChannelIds: [String]
            var categories: [Category]

            enum CodingKeys: String, CodingKey {
                case discoverNewChannelIds = "discoverNew"
                case categories
            }

            init(from decoder: any Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                discoverNewChannelIds = try container.decode([String].self, forKey: .discoverNewChannelIds)
                categories = try container.decode([String: Category].self, forKey: .categories)
                    .map { key, category in
                        var category = category
                        category.key = key
                        return category
                    }
                    .sorted(by: { $0.sortOrder < $1.sortOrder })
            }
        }
    }

    private static func loadRemoteCategories() async throws {
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil

        let session = URLSession(configuration: config)
        let req = URLRequest(url: endpoint)

        let (data, urlResponse) = try await session.data(for: req)

        guard let httpResponse = urlResponse as? HTTPURLResponse else {
            throw LbryioRequestError.invalidResponse(urlResponse)
        }
        let respCode = httpResponse.statusCode

        guard respCode >= 200 && respCode < 300 else {
            let response = try JSONDecoder().decode(ErrorResponse.self, from: data)

            throw LbryioResponseError.error(response.error ?? "Unknown Content Sources API error", respCode)
        }

        var languageKey = Locale.current.languageCode ?? languageCodeEN
        let regionCode = Locale.current.regionCode ?? regionCodeUS
        if languageKey != languageCodeEN, regionCode == regionCodeBR {
            languageKey = "\(languageKey)-\(regionCode)"
        }

        let response = try JSONDecoder().decode(ContentSourcesResponse.self, from: data)

        guard let langData = response.data[languageKey] ?? response.data[languageCodeEN] else {
            throw LbryioResponseError.error("No Homepage found for current Locale and/or English", respCode)
        }

        // FIXME: Use `discoverCategory` (with pinned, etc)
        var categories = langData.categories.filter { $0.key != discoverCategory }
        categories.insert(
            Category(
                key: HomeViewController.categoryKeyDiscover,
                sortOrder: 1,
                name: HomeViewController.categoryKeyDiscover,
                label: "Discover",
                channelLimit: 1,
                channelIds: langData.discoverNewChannelIds,
                excludedChannelIds: []
            ),
            at: 0
        )

        DynamicContentCategories = categories

        if categories.count > 0 {
            // cache the categories
            let csCache = ContentSourceCache(categories: categories, lastUpdated: Date())
            let data = try JSONEncoder().encode(csCache)
            UserDefaults.standard.setValue(String(data: data, encoding: .utf8), forKey: defaultsKey)
        }
    }

    struct Category: Codable {
        /// Decoding: `key` if present, else empty; will be set from decoded Dict key
        /// Encoding: Always present
        var key: String

        var sortOrder: Int
        var name: String
        var label: String
        /// Codable as String
        var channelLimit: Int
        var channelIds: [String]
        var excludedChannelIds: [String]

        init(
            key: String,
            sortOrder: Int,
            name: String,
            label: String,
            channelLimit: Int,
            channelIds: [String],
            excludedChannelIds: [String]
        ) {
            self.key = key
            self.sortOrder = sortOrder
            self.name = name
            self.label = label
            self.channelLimit = channelLimit
            self.channelIds = channelIds
            self.excludedChannelIds = excludedChannelIds
        }

        enum CodingKeys: CodingKey {
            case key
            case sortOrder
            case name
            case label
            case channelLimit
            case channelIds
            case excludedChannelIds
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            key = try container.decodeIfPresent(String.self, forKey: .key) ?? ""
            sortOrder = try container.decode(Int.self, forKey: .sortOrder)
            name = try container.decode(String.self, forKey: .name)
            label = try container.decode(String.self, forKey: .label)
            channelLimit = try Int(container.decodeIfPresent(String.self, forKey: .channelLimit) ?? "1") ?? 1
            channelIds = try container.decodeIfPresent([String].self, forKey: .channelIds) ?? []
            excludedChannelIds = try container.decodeIfPresent([String].self, forKey: .excludedChannelIds) ?? []
        }

        func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(key, forKey: .key)
            try container.encode(sortOrder, forKey: .sortOrder)
            try container.encode(name, forKey: .name)
            try container.encode(label, forKey: .label)
            try container.encode(String(channelLimit), forKey: .channelLimit)
            try container.encode(channelIds, forKey: .channelIds)
            try container.encode(excludedChannelIds, forKey: .excludedChannelIds)
        }
    }

    struct ContentSourceCache: Codable {
        var categories: [Category] = []
        var lastUpdated = Date()
    }
}
