//
//  SharedPreference+Blocked.swift
//  Odysee
//
//  Created by Keith on 15/07/2026.
//

import Foundation

extension SharedPreference {
    typealias Block = LbryUri
}

extension SharedPreference.Block {
    init(channelName: String, claimId: String) throws {
        let channelName = channelName.starts(with: "@") ? channelName : "@\(channelName)"
        self = try LbryUri.parse(url: "lbry://\(channelName):\(claimId)", requireProto: true)
    }
}

// MARK: - Mutators and Predicates

extension SharedPreference {
    mutating func addBlocked(channelName: String, claimId: String) {
        guard !Lbry.ownChannels.contains(where: { $0.claimId == claimId }) else {
            return
        }

        guard let block = try? Block(channelName: channelName, claimId: claimId),
              !blocked.contains(block)
        else {
            return
        }

        blocked.append(block)
    }

    mutating func removeBlocked(claimId: String) {
        blocked.removeAll { $0.claimId == claimId }
    }

    func isBlocked(claimId: String) -> Bool {
        return blocked.contains { $0.claimId == claimId }
    }
}
