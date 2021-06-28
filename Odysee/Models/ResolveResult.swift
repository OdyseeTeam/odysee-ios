//
//  ResolveResult.swift
//  Odysee
//
//  Created by Adlai Holler on 6/17/21.
//

struct ResolveResult: Decodable {
    var claims = [String: Claim]()
    var errors = [String: Error]()

    init(from decoder: Decoder) throws {
        let dict = try [String: ResolveItemResult](from: decoder)
        claims.reserveCapacity(dict.count)
        for (key, val) in dict {
            switch val {
            case let .success(claim):
                claims[key] = claim
            case let .failure(error):
                errors[key] = error
            }
        }
    }
}

private struct ResolveError: Decodable, Error {
    var name: String?
    var text: String?
}

// Similar to Swift.Result<Claim, Error> but decodable.
private enum ResolveItemResult: Decodable {
    case failure(Error)
    case success(Claim)
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let error = try container.decodeIfPresent(ResolveError.self, forKey: CodingKeys.error) {
            self = .failure(error)
            return
        }
        let claim = try Claim(from: decoder)
        if claim.claimId != nil {
            self = .success(claim)
        } else {
            assertionFailure()
            self = .failure(GenericError("Failed to decode resolve result"))
        }
    }

    enum CodingKeys: String, CodingKey {
        case error
    }
}
