//
//  Lbry.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 02/11/2020.
//

import Foundation

final class Lbry {
    static let ttlCLaimSearchValue = 120000
    static let lbrytvConnectionString = "https://api.lbry.tv/api/v1/proxy"
    
    static let methodClaimSearch = "claim_search"
    static let methodResolve = "resolve"
    
    static func apiCall(method: String, params: Dictionary<String, Any>, connectionString: String, completion: @escaping ([String: Any]?, Error?) -> Void) {
        let counter = Date().timeIntervalSince1970
        let url = URL(string: connectionString)!
        let body: Dictionary<String, Any> = [
            "jsonrpc": "2.0",
            "method": method,
            "params": params,
            "counter": counter
        ];
        
        let session = URLSession.shared
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        do {
            req.httpBody = try JSONSerialization.data(withJSONObject: body, options: .prettyPrinted)
        } catch let error {
            completion(nil, error)
            return
        }
        
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let task = session.dataTask(with: req, completionHandler: { data, response, error in
            guard let data = data, error == nil else {
                // handle error
                completion(nil, error)
                return
            }
            do {
                let response = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                completion(response, nil)
            } catch let error {
                completion(nil, error)
            }
        });
        task.resume();
    }
    
    static func buildClaimSearchOptions(
        claimType: [String]?,
        anyTags: [String]?,
        notTags: [String]?,
        channelIds: [String]?,
        notChannelIds: [String]?,
        orderBy: [String]?,
        releaseTime: String?,
        maxDuration: Int64?,
        limitClaimsPerChannel: Int,
        page: Int,
        pageSize: Int) -> Dictionary<String, Any> {
        var options: Dictionary<String, Any> = [String: Any]()
        
        if (claimType != nil) {
            options["claim_type"] = claimType
        }
        options["no_totals"] = true
        options["page"] = page
        options["page_size"] = pageSize
        if (!(releaseTime ?? "").isBlank) {
            options["release_time"] = releaseTime
        }
        if ((maxDuration ?? 0) > 0) {
            options["duration"] = String(format: "<%d", maxDuration!)
        }
        if (limitClaimsPerChannel > 0) {
            options["limit_claims_per_channel"] = limitClaimsPerChannel
        }
        
        addClaimSearchListOption(key: "any_tags", list: anyTags, options: &options)
        addClaimSearchListOption(key: "not_tags", list: notTags, options: &options)
        addClaimSearchListOption(key: "channel_ids", list: channelIds, options: &options)
        addClaimSearchListOption(key: "not_channel_ids", list: notChannelIds, options: &options)
        addClaimSearchListOption(key: "order_by", list: orderBy, options: &options)
        
        return options
    }
    
    static func addClaimSearchListOption(key: String, list: [String]?, options: inout Dictionary<String, Any>) {
        if ((list ?? []).count > 0) {
            options[key] = list
        }
    }
}
