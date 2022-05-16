//
//  ContentSources.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 04/11/2020.
//

import Foundation

struct ContentSources {
    static let languageCodeEN = "en"
    static let regionCodeUS = "US"
    static let regionCodeBR = "BR" // special check for pt-BR

    static let defaultsKey = "ContentSourcesCache"
    static let endpoint = "https://odysee.com/$/api/content/v2/get"

    static var DynamicContentCategories: [Category] = []

    static func loadCategories(completion: @escaping ([Category]?, Error?) -> Void) {
        let defaults = UserDefaults.standard

        do {
            if let csCacheString = defaults.string(forKey: defaultsKey) {
                let csCache = try JSONDecoder().decode(ContentSourceCache.self, from: csCacheString.data(using: .utf8)!)
                if let diff = Calendar.current.dateComponents([.hour], from: csCache.lastUpdated, to: Date()).hour,
                   diff < 24
                {
                    ContentSources.DynamicContentCategories = csCache.categories
                    completion(csCache.categories, nil)
                    return
                }
            }
        } catch { /* Fall through to loadRemoteCategories */ }

        loadRemoteCategories(completion: completion)
    }

    static func loadRemoteCategories(completion: @escaping ([Category]?, Error?) -> Void) {
        let requestUrl = URL(string: ContentSources.endpoint)
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil

        let session = URLSession(configuration: config)
        let req = URLRequest(url: requestUrl!)
        let task = session.dataTask(with: req, completionHandler: { data, response, error in
            guard let data = data, error == nil else {
                // handle error
                completion(nil, error)
                return
            }

            do {
                var respCode = 0
                if let httpResponse = response as? HTTPURLResponse {
                    respCode = httpResponse.statusCode
                }
                let respData = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]

                Log.verboseJSON.logIfEnabled(.debug, String(data: data, encoding: .utf8)!)
                if respCode >= 200, respCode < 300 {
                    if respData?["data"] == nil {
                        completion(nil, LbryioResponseError("Could not find data key in response returned", respCode))
                        return
                    }

                    var categories: [Category] = []
                    if let data = respData?["data"] as? [String: Any] {
                        var languageKey = Locale.current.languageCode ?? languageCodeEN
                        let regionCode = Locale.current.regionCode ?? regionCodeUS
                        if languageKey != languageCodeEN, regionCode == regionCodeBR {
                            languageKey = String(format: "%@-%@", languageKey, regionCode)
                        }

                        if let langData = data[languageKey] as? [String: Any] ?? data[languageCodeEN] as? [String: Any],
                           let langCategories = langData["categories"] as? [String: Any]
                        {
                            let keys = Array(langCategories.keys)
                            for key in keys {
                                if let contentSource = langCategories[key] as? [String: Any] {
                                    if let label = contentSource["label"] as? String,
                                       let name = contentSource["name"] as? String,
                                       let sortOrder = contentSource["sortOrder"] as? Int
                                    {
                                        let channelIds = contentSource["channelIds"] as? [String] ?? []
                                        let excludedChannelIds = contentSource["excludedChannelIds"] as? [String] ?? []
                                        let category = Category(
                                            sortOrder: sortOrder,
                                            key: key,
                                            name: name,
                                            label: label,
                                            channelIds: channelIds,
                                            excludedChannelIds: excludedChannelIds
                                        )
                                        categories.append(category)
                                    }
                                }
                            }
                        }
                    }

                    categories.sort(by: { $0.sortOrder < $1.sortOrder })
                    ContentSources.DynamicContentCategories = categories

                    // cache the categories
                    let csCache = ContentSourceCache(categories: categories, lastUpdated: Date())
                    UserDefaults.standard.setValue(
                        String(data: try! JSONEncoder().encode(csCache), encoding: .utf8),
                        forKey: defaultsKey
                    )

                    completion(categories, nil)
                    return
                }

                if respData?["error"] as? NSNull != nil {
                    completion(nil, LbryioResponseError("no error message", respCode))
                } else if respData?["error"] as? String != nil {
                    completion(nil, LbryioResponseError(respData?["error"] as! String, respCode))
                } else {
                    completion(nil, LbryioResponseError("Unknown api error signature", respCode))
                }
            } catch let err {
                completion(nil, err)
            }
        })
        task.resume()
    }

    struct Category: Codable {
        var sortOrder: Int
        var key: String = ""
        var name: String
        var label: String
        var channelIds: [String] = []
        var excludedChannelIds: [String] = []
    }

    struct ContentSourceCache: Codable {
        var categories: [Category] = []
        var lastUpdated = Date()
    }
}
