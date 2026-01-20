//
//  ContentSources.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 04/11/2020.
//

import Foundation

enum ContentSources {
    static let languageCodeEN = "en"
    static let regionCodeUS = "US"
    static let regionCodeBR = "BR" // special check for pt-BR

    static let defaultsKey = "ContentSourcesCache"
    static let endpoint = "https://odysee.com/$/api/content/v2/get"

    static let discoverCategory = "EXPLORABLE_CHANNEL"

    static let placeholderDiscoverCategory = Category(
        sortOrder: 1,
        key: HomeViewController.categoryKeyDiscover,
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

    static func loadCategories(completion: @escaping (Error?) -> Void) {
        let defaults = UserDefaults.standard

        do {
            if let csCacheString = defaults.string(forKey: defaultsKey) {
                let csCache = try JSONDecoder().decode(ContentSourceCache.self, from: csCacheString.data)
                if let diff = Calendar.current.dateComponents([.hour], from: csCache.lastUpdated, to: Date()).hour,
                   diff < 24
                {
                    ContentSources.DynamicContentCategories = csCache.categories
                    completion(nil)
                    return
                }
            }
        } catch {
            /* Fall through to loadRemoteCategories */
        }

        loadRemoteCategories(completion: completion)
    }

    static func loadRemoteCategories(completion: @escaping (Error?) -> Void) {
        guard let requestUrl = URL(string: ContentSources.endpoint) else {
            completion(GenericError("requestUrl"))
            return
        }

        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil

        let session = URLSession(configuration: config)
        let req = URLRequest(url: requestUrl)
        let task = session.dataTask(with: req, completionHandler: { data, response, error in
            guard let data = data, error == nil else {
                // handle error
                completion(error)
                return
            }

            do {
                var respCode = 0
                if let httpResponse = response as? HTTPURLResponse {
                    respCode = httpResponse.statusCode
                }
                let respData = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]

                if let string = String(data: data, encoding: .utf8) {
                    Log.verboseJSON.logIfEnabled(.debug, string)
                }

                if respCode >= 200, respCode < 300 {
                    if respData?["data"] == nil {
                        completion(LbryioResponseError.error("Could not find data key in response returned", respCode))
                        return
                    }

                    var categories: [Category] = []
                    if let data = respData?["data"] as? [String: Any] {
                        var languageKey = Locale.current.languageCode ?? languageCodeEN
                        let regionCode = Locale.current.regionCode ?? regionCodeUS
                        if languageKey != languageCodeEN, regionCode == regionCodeBR {
                            languageKey = "\(languageKey)-\(regionCode)"
                        }

                        if let langData = data[languageKey] as? [String: Any] ?? data[languageCodeEN] as? [String: Any],
                           let langCategories = langData["categories"] as? [String: Any],
                           let langDiscoverNew = langData["discoverNew"] as? [String]
                        {
                            let keys = Array(langCategories.keys)
                            for key in keys where key != discoverCategory {
                                if let contentSource = langCategories[key] as? [String: Any] {
                                    if let label = contentSource["label"] as? String,
                                       let name = contentSource["name"] as? String,
                                       let sortOrder = contentSource["sortOrder"] as? Int
                                    {
                                        let channelIds = contentSource["channelIds"] as? [String] ?? []
                                        let excludedChannelIds = contentSource["excludedChannelIds"] as? [String] ?? []
                                        let channelLimit = Int(contentSource["channelLimit"] as? String ?? "1") ?? 1
                                        let category = Category(
                                            sortOrder: sortOrder,
                                            key: key,
                                            name: name,
                                            label: label,
                                            channelLimit: channelLimit,
                                            channelIds: channelIds,
                                            excludedChannelIds: excludedChannelIds
                                        )
                                        categories.append(category)
                                    }
                                }
                            }

                            categories.append(Category(
                                sortOrder: 1,
                                key: HomeViewController.categoryKeyDiscover,
                                name: HomeViewController.categoryKeyDiscover,
                                label: "Discover",
                                channelLimit: 1,
                                channelIds: langDiscoverNew,
                                excludedChannelIds: []
                            ))
                        }
                    }

                    categories.sort(by: { $0.sortOrder < $1.sortOrder })
                    ContentSources.DynamicContentCategories = categories

                    if categories.count > 0 {
                        // cache the categories
                        let csCache = ContentSourceCache(categories: categories, lastUpdated: Date())
                        do {
                            let data = try JSONEncoder().encode(csCache)
                            UserDefaults.standard.setValue(
                                String(data: data, encoding: .utf8),
                                forKey: defaultsKey
                            )
                        } catch {
                            completion(error)
                            return
                        }
                    }

                    completion(nil)
                    return
                }

                if respData?["error"] as? NSNull != nil {
                    completion(LbryioResponseError.error("no error message", respCode))
                } else if let error = respData?["error"] as? String {
                    completion(LbryioResponseError.error(error, respCode))
                } else {
                    completion(LbryioResponseError.error("Unknown api error signature", respCode))
                }
            } catch let err {
                completion(err)
            }
        })
        task.resume()
    }

    struct Category: Codable {
        var sortOrder: Int
        var key: String = ""
        var name: String
        var label: String
        var channelLimit: Int
        var channelIds: [String] = []
        var excludedChannelIds: [String] = []
    }

    struct ContentSourceCache: Codable {
        var categories: [Category] = []
        var lastUpdated = Date()
    }
}
