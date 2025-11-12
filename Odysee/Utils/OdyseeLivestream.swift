//
//  OdyseeLivestream.swift
//  Odysee
//
//  Created by Keith Toh on 22/04/2022.
//

import Foundation

struct OdyseeLivestream {
    static let allEndpoint = URL(string: "https://api.odysee.live/livestream/all")!
    static let isLiveEndpoint = "https://api.odysee.live/livestream/is_live?channel_claim_id=%@"

    static func all(completion: @escaping (_ result: Result<[LivestreamInfo], Error>) -> Void) {
        DispatchQueue.global().async {
            do {
                let data = try Data(contentsOf: allEndpoint)

                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601

                let result = try decoder.decode(OLAllResult.self, from: data)
                if result.success, result.error == nil, let data = result.data {
                    let livestreamInfos = data
                        .filter { $0.activeClaim.claimId != "Confirming" }
                        .filter(\.live)
                        .map {
                            LivestreamInfo(
                                startTime: $0.startTime,
                                viewerCount: $0.viewerCount,
                                channelClaimId: $0.channelClaimId,
                                activeClaimId: $0.activeClaim.claimId
                            )
                        }

                    completion(.success(livestreamInfos))
                    return
                } else if result.data == nil,
                          let error = result.error,
                          let trace = result.trace
                {
                    completion(.failure(OdyseeLivestreamError.runtimeError("\(error)\n---Trace---\n\(trace)")))
                    return
                }

                completion(.failure(OdyseeLivestreamError.unknown))
            } catch {
                completion(.failure(error))
            }
        }
    }

    static func channelIsLive(
        channelClaimId: String,
        completion: @escaping (_ result: Result<ChannelLiveInfo, Error>) -> Void
    ) {
        DispatchQueue.global().async {
            do {
                guard let url = URL(string: String(format: isLiveEndpoint, channelClaimId)) else {
                    completion(.failure(OdyseeLivestreamError.couldNotCreateUrl))
                    return
                }

                let data = try Data(contentsOf: url)

                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601

                let result = try decoder.decode(OLIsLiveResult.self, from: data)
                if result.success, result.error == nil, let data = result.data {
                    completion(.success(ChannelLiveInfo(
                        live: data.live,
                        startTime: data.startTime,
                        viewerCount: data.viewerCount,
                        channelClaimId: data.channelClaimId,
                        activeClaimUrl: data.activeClaim.canonicalUrl,
                        futureClaimsUrls: data.futureClaims?.map(\.canonicalUrl)
                    )))
                    return
                } else if result.data == nil,
                          let error = result.error,
                          let trace = result.trace
                {
                    completion(.failure(OdyseeLivestreamError.runtimeError("\(error)\n---Trace---\n\(trace)")))
                    return
                }

                completion(.failure(OdyseeLivestreamError.unknown))
            } catch {
                completion(.failure(error))
            }
        }
    }

    struct OLAllResult: Decodable {
        var success: Bool
        var error: String?
        var data: [OLLivestream]?
        var trace: [String]?

        enum CodingKeys: String, CodingKey {
            case success
            case error
            case data
            case trace = "_trace"
        }
    }

    struct OLIsLiveResult: Decodable {
        var success: Bool
        var error: String?
        var data: OLLivestream?
        var trace: [String]?

        enum CodingKeys: String, CodingKey {
            case success
            case error
            case data
            case trace = "_trace"
        }
    }

    struct OLLivestream: Decodable {
        var live: Bool
        var startTime: Date
        var viewerCount: Int
        var channelClaimId: String
        var activeClaim: OLClaim
        var futureClaims: [OLClaim]?

        enum CodingKeys: String, CodingKey {
            case live = "Live"
            case startTime = "Start"
            case viewerCount = "ViewerCount"
            case channelClaimId = "ChannelClaimID"
            case activeClaim = "ActiveClaim"
            case futureClaims = "FutureClaims"
        }
    }

    struct OLClaim: Decodable {
        var claimId: String
        var canonicalUrl: String

        enum CodingKeys: String, CodingKey {
            case claimId = "ClaimID"
            case canonicalUrl = "CanonicalURL"
        }
    }
}

struct LivestreamInfo {
    var startTime: Date
    var viewerCount: Int
    var channelClaimId: String
    var activeClaimId: String
}

struct ChannelLiveInfo {
    var live: Bool
    var startTime: Date
    var viewerCount: Int
    var channelClaimId: String
    var activeClaimUrl: String
    var futureClaimsUrls: [String]?
}

/// Used by external files for associating claims with details about them as a livestream
struct LivestreamData: Hashable {
    var startTime: Date
    var viewerCount: Int
    var claim: Claim
}

enum OdyseeLivestreamError: LocalizedError {
    case unknown
    case couldNotCreateUrl
    case runtimeError(String)

    var errorDescription: String? {
        switch self {
        case .unknown:
            return String.localized("Unknown error occurred")
        case .couldNotCreateUrl:
            return String.localized("Endpoint URL could not be created")
        case let .runtimeError(message):
            return String(format: String.localized("Runtime error: %@"), message)
        }
    }
}
