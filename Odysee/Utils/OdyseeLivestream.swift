//
//  ListLivestreams.swift
//  Odysee
//
//  Created by Keith Toh on 22/04/2022.
//

import Foundation

struct OdyseeLivestream {
    static let allEndpoint = URL(string: "https://api.odysee.live/livestream/all")!
    static let isLiveEndpoint = "https://api.odysee.live/livestream/is_live?channel_claim_id=%@"

    static func all(completion: @escaping (_ result: Result<[String: LivestreamInfo], Error>) -> Void) {
        do {
            let data = try Data(contentsOf: allEndpoint)

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let result = try decoder.decode(OLAllResult.self, from: data)
            if result.success, result.error == nil, let data = result.data {
                let livestreamInfos = Dictionary(
                    uniqueKeysWithValues: data
                        .filter { $0.activeClaim.claimId != "Confirming" }
                        .map {
                            (
                                $0.activeClaim.claimId,
                                LivestreamInfo(
                                    live: $0.live,
                                    startTime: $0.startTime,
                                    viewerCount: $0.viewerCount,
                                    channelClaimId: $0.channelClaimId
                                )
                            )
                        }
                )
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

    static func channelIsLive(channelClaimId: String, completion: @escaping (_ result: Result<(String, LivestreamInfo), Error>) -> Void) {
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
                completion(.success((
                    data.activeClaim.canonicalUrl,
                    LivestreamInfo(
                        live: data.live,
                        startTime: data.startTime,
                        viewerCount: data.viewerCount,
                        channelClaimId: data.channelClaimId
                    )
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

        enum CodingKeys: String, CodingKey {
            case live = "Live"
            case startTime = "Start"
            case viewerCount = "ViewerCount"
            case channelClaimId = "ChannelClaimID"
            case activeClaim = "ActiveClaim"
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

struct LivestreamInfo: Hashable {
    var live: Bool
    var startTime: Date
    var viewerCount: Int
    var channelClaimId: String
}

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
