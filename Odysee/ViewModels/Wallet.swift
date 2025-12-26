//
//  Wallet.swift
//  Odysee
//
//  Created by Keith Toh on 18/12/2025.
//

import Combine
import Foundation

actor Wallet {
    static let shared = Wallet()

    static let syncInterval: UInt64 = 300_000_000_000 // 5 minutes

    @Published var following: Following = [:]

    private var localWalletHash: String?
    private var remoteWalletHash: String?

    private var sync: Task<Void, any Error>?

    private init() {
        Task {
            await startSync()
        }
    }

    func startSync() {
        guard Lbryio.isSignedIn(), sync == nil else {
            return
        }

        sync = Task {
            while true {
                do {
                    _ = try await pullSync()
                } catch {
                    await Helper.showError(error: error)
                }
                try await Task.sleep(nanoseconds: Self.syncInterval)
            }
        }
    }

    func stopSync() {
        sync?.cancel()
        sync = nil
    }

    // FIXME: Need to check in progress? With another actor?
    func pullSync() async throws -> SharedPreference {
        let hash = try await LbryMethods.syncHash.call(params: .init())

        localWalletHash = hash

        // FIXME: needs new wallet?
        // Handle, nil data for sync_apply
        let walletSync = try await LbryioMethods.syncGet.call(
            params: .init(hash: hash)
        )

        remoteWalletHash = walletSync.hash

        if let data = walletSync.data,
           walletSync.changed || localWalletHash != remoteWalletHash
        {
            let syncApply = try await LbryMethods.syncApply.call(
                params: .init(data: data, blocking: true)
            )

            localWalletHash = syncApply.hash
        }

        let sharedPreference = try await LbryMethods.sharedPreferenceGet.call(params: .init())

        // FIXME: No loop
        following = try sharedPreference.following.reduce(into: Following()) {
            guard let channelName = $1.uri.channelName,
                  let claimId = $1.uri.channelClaimId
            else {
                return
            }
            try $0[LbryUri.parse(
                url: "lbry://@\(channelName):\(claimId)", requireProto: true
            )] = $1.notificationsDisabled
        }

        return sharedPreference
    }

    func pushSync() async throws {
        var sharedPreference = try await pullSync()

        sharedPreference.following = following.map {
            SharedPreference.Following(
                notificationsDisabled: $0.value,
                uri: $0.key
            )
        }

        _ = try await LbryMethods.sharedPreferenceSet.call(params: .init(value: sharedPreference))
    }
}
