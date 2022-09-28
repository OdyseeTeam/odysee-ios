//
//  MembershipPerk.swift
//  Odysee
//
//  Created by Keith Toh on 26/09/2022.
//

import Foundation

struct MembershipPerk {
    static let checkApiEndpoint = "https://api.odysee.com/membership_perk/check"

    static func perkCheck(
        authToken: String?,
        claimId: String?,
        type: ContentType,
        completion: @escaping (_ result: Result<Bool, Error>) -> Void
    ) {
        do {
            var components = URLComponents(string: checkApiEndpoint)
            components?.queryItems = [
                URLQueryItem(name: "auth_token", value: authToken),
                URLQueryItem(name: "claim_id", value: claimId),
                URLQueryItem(name: "type", value: type.rawValue)
            ]
            guard let url = components?.url else {
                completion(.failure(MembershipPerkError.couldNotCreateUrl))
                return
            }

            let response = try Data(contentsOf: url)
            let json = try JSONSerialization.jsonObject(with: response, options: []) as? [String: Any]

            if json?["success"] as? Bool ?? false {
                guard let data = json?["data"] as? [String: Any],
                      let hasAccess = data["has_access"] as? Bool
                else {
                    completion(.failure(MembershipPerkError.noData))
                    return
                }

                completion(.success(hasAccess))
            } else {
                if let error = json?["error"] as? String {
                    completion(.failure(MembershipPerkError.apiError(error)))
                } else {
                    completion(.failure(MembershipPerkError.apiError("unknown api error")))
                }
            }
        } catch {
            completion(.failure(error))
        }
    }

    enum ContentType: String {
        case content = "Exclusive content"
        case livestream = "Exclusive livestreams"
    }
}

enum MembershipPerkError: LocalizedError {
    case couldNotCreateUrl
    case noData
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .couldNotCreateUrl:
            return String.localized("endpoint URL could not be created.")
        case .noData:
            return String.localized("no data returned")
        case let .apiError(error):
            return error
        }
    }
}
