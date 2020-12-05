//
//  Lbry.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 02/11/2020.
//

import Base58Swift
import CryptoKit
import Foundation

final class Lbry {
    static let ttlCLaimSearchValue = 120000
    static let lbrytvConnectionString = "https://api.lbry.tv/api/v1/proxy"
    
    static let methodClaimSearch = "claim_search"
    static let methodResolve = "resolve"
    
    static let methodPreferenceGet = "preference_get"
    static let methodPreferenceSet = "preference_set"
    static let methodSyncHash = "sync_hash"
    static let methodSyncApply = "sync_apply"
    static let methodTransactionList = "transaction_list"
    static let methodWalletBalance = "wallet_balance"
    static let methodWalletStatus = "wallet_status"
    static let methodWalletUnlock = "wallet_unlock"
    static let methodWalletSend = "wallet_send"
    
    static let methodAddressUnused = "address_unused"
    
    static var installationId: String? = nil
    static let keyInstallationId = "AppInstallationId"
    
    static var remoteWalletHash: String? = nil
    static var localWalletHash: String? = nil
    static var walletBalance: WalletBalance? = nil
    
    static var claimCacheById: Dictionary<String, Claim> = Dictionary<String, Claim>()
    static var claimCacheByUrl: Dictionary<String, Claim> = Dictionary<String, Claim>()
    
    static func apiCall(method: String, params: Dictionary<String, Any>, connectionString: String, authToken: String? = nil, completion: @escaping ([String: Any]?, Error?) -> Void) {
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
        if (!(authToken ?? "").isBlank) {
            req.addValue(authToken!, forHTTPHeaderField: "X-Lbry-Auth-Token")
        }
        
        let task = session.dataTask(with: req, completionHandler: { data, response, error in
            guard let data = data, error == nil else {
                // handle error
                completion(nil, error)
                return
            }
            do {
                // TODO: remove
                if let JSONString = String(data: data, encoding: String.Encoding.utf8) {
                   print(JSONString)
                }
                
                let response = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                if (response?["result"] != nil) {
                    completion(response, nil)
                } else {
                    if (response?["error"] as? String != nil) {
                        completion(nil, LbryApiResponseError.runtimeError(response?["error"] as! String))
                    } else if let errorJson = response?["error"] as? [String: Any] {
                        completion(nil, LbryApiResponseError.runtimeError(errorJson["message"] as! String))
                    } else {
                        completion(nil, LbryApiResponseError.runtimeError("unknown api error"))
                    }
                }
            } catch let error {
                completion(nil, error)
            }
        });
        task.resume();
    }
    
    static func addClaimToCache(claim: Claim?) {
        if (claim != nil) {
            Lbry.claimCacheById[(claim?.claimId!)!] = claim
            let claimUrl: LbryUri? = LbryUri.tryParse(url: (claim?.permanentUrl!)!, requireProto: false)
            if (claimUrl != nil) {
                Lbry.claimCacheByUrl[(claimUrl?.description)!] = claim
            }
        }
    }
    
    static func buildClaimSearchOptions(
        claimType: [String]?,
        anyTags: [String]?,
        notTags: [String]?,
        channelIds: [String]?,
        notChannelIds: [String]?,
        claimIds: [String]?,
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
        addClaimSearchListOption(key: "claim_ids", list: claimIds, options: &options)
        addClaimSearchListOption(key: "order_by", list: orderBy, options: &options)
        
        return options
    }
    
    static func addClaimSearchListOption(key: String, list: [String]?, options: inout Dictionary<String, Any>) {
        if ((list ?? []).count > 0) {
            options[key] = list
        }
    }
    
    static func generateId() -> String? {
        return generateId(numBytes: 64)
    }
    static func generateId(numBytes: Int) -> String? {
        var data = Data(count: numBytes)
        let result = data.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, numBytes, $0.baseAddress!)
        }
        if (result == errSecSuccess) {
            let hash = SHA384.hash(data: data)
            return Base58.base58Encode(Array(hash.makeIterator()))
        }
        return nil
    }
}

enum LbryApiResponseError: Error {
    case runtimeError(String)
}
