//
//  Lighthouse.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 12/11/2020.
//

import Foundation

final class Lighthouse {
    static let connectionString = "https://lighthouse.lbry.com"
    
    static var relatedContentCache: Dictionary<String, Any> = [:]
    
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
        "covid 19"
    ]
    
    static func search(rawQuery: String, size: Int, from: Int, relatedTo: String?, completion: @escaping ([[String: Any]]?, Error?) -> Void) {
        if !(relatedTo ?? "").isBlank {
            if let respData = relatedContentCache[String(format: "%@:%@", relatedTo!, rawQuery)] {
                completion(respData as? [[String: Any]], nil)
                return
            }
        }
        
        for keyword in keywordsForEmptyResults {
            let trimmedQuery = rawQuery.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedQuery.contains(keyword) || trimmedQuery == keyword {
                completion([], nil)
                return
            }
            if relatedTo != nil && (relatedTo!.contains(keyword) || relatedTo == keyword) {
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
        if (!(relatedTo ?? "").isBlank) {
            queryItems.append(URLQueryItem(name: "related_to", value: String(relatedTo!)))
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
                var respCode:Int = 0
                if let httpResponse = response as? HTTPURLResponse {
                    respCode = httpResponse.statusCode
                }
                let respData = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]]
                if (respCode == 200) {
                    if !(relatedTo ?? "").isBlank {
                        relatedContentCache[String(format: "%@:%@", relatedTo!, rawQuery)] = respData
                    }
                    completion(respData, nil)
                } else {
                    completion([], nil)
                }
            } catch let error {
                completion([], error)
            }
        })
        task.resume()
    }
}
